// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@faircrypto/xen-crypto/contracts/XENCrypto.sol";
import "@faircrypto/xen-crypto/contracts/interfaces/IBurnableToken.sol";
import "@faircrypto/xen-crypto/contracts/interfaces/IBurnRedeemable.sol";
import "@faircrypto/magic-numbers/contracts/MagicNumbers.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";
import "./interfaces/IXENBurner.sol";
import "./interfaces/IXENBurn.sol";
import "./interfaces/IERC2771.sol";
import "./libs/ERC2771Context.sol";
import "./libs/BurnInfo.sol";
import "./libs/BurnMetadata.sol";
import "./libs/Array.sol";

/*

        \\      //   |||||||||||   |\      ||       A CRYPTOCURRENCY FOR THE MASSES
         \\    //    ||            |\\     ||
          \\  //     ||            ||\\    ||       PRINCIPLES OF XEN:
           \\//      ||            || \\   ||       - No pre-mint; starts with zero supply
            XX       ||||||||      ||  \\  ||       - No admin keys
           //\\      ||            ||   \\ ||       - Immutable contract
          //  \\     ||            ||    \\||
         //    \\    ||            ||     \\|
        //      \\   |||||||||||   ||      \|       Copyright (C) FairCrypto Foundation 2022-23


    XENFT XEN Burn props:
    - burned/amount: XEN burned,
    - burnTs,
    - rarityScore
 */
contract XENBurn is
    IXENBurn,
    IBurnRedeemable,
    IXENBurner,
    DefaultOperatorFilterer, // required to support OpenSea royalties
    ERC2771Context, // required to support meta transactions
    IERC2981, // required to support NFT royalties
    ERC721("XEN Burn", "XENB")
{
    // HELPER LIBRARIES

    using Strings for uint256;
    using BurnInfo for uint256;
    using MagicNumbers for uint256;
    using Array for uint256[];

    // PUBLIC CONSTANTS

    string public constant AUTHORS = "@MrJackLevin @lbelyaev faircrypto.org";

    uint256 public constant ROYALTY_BP = 500;

    // PUBLIC MUTABLE STATE

    // increasing counters for NFT tokenIds
    uint256 public tokenIdCounter = 1;
    // mapping: NFT tokenId => burned XEN
    mapping(uint256 => uint256) public xenBurned;
    // tokenId => burnInfo
    mapping(uint256 => uint256) public burnInfo;

    // PUBLIC IMMUTABLE STATE

    // pointer to XEN Crypto contract
    XENCrypto public immutable xenCrypto;

    // PRIVATE STATE

    // original deployer address to be used for setting trusted forwarder
    address private immutable _deployer;
    // address to be used for royalties' tracking
    address private immutable _royaltyReceiver;

    // mapping Address => tokenId[]
    mapping(address => uint256[]) private _ownedTokens;

    // reentrancy guard constants and state
    // using non-zero constants to save gas avoiding repeated initialization
    uint256 private constant _NOT_USED = 2**256 - 1; // 0xFF..FF
    // used as both
    // - reentrancy guard (_NOT_USED > tokenId > _NOT_USED)
    // - for keeping state while awaiting for OnTokenBurned callback (_NOT_USED > tokenId > _NOT_USED)
    uint256 private _tokenId = _NOT_USED;

    /**
        @dev    Constructor. Creates XEN Burn contract, setting immutable parameters
     */
    constructor(
        address xenCrypto_,
        address forwarder_,
        address royaltyReceiver_
    ) ERC2771Context(forwarder_) {
        require(xenCrypto_ != address(0), "bad address");
        xenCrypto = XENCrypto(xenCrypto_);
        _deployer = msg.sender;
        _royaltyReceiver = royaltyReceiver_ == address(0) ? msg.sender : royaltyReceiver_;
    }

    // INTERFACES & STANDARDS
    // IERC165 IMPLEMENTATION

    /**
        @dev confirms support for IERC-165, IERC-721, IERC2981, IERC2771 and IBurnRedeemable interfaces
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return
        interfaceId == type(IBurnRedeemable).interfaceId ||
        interfaceId == type(IERC2981).interfaceId ||
        interfaceId == type(IERC2771).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    // ERC2771 IMPLEMENTATION

    /**
        @dev use ERC2771Context implementation of _msgSender()
     */
    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    /**
        @dev use ERC2771Context implementation of _msgData()
     */
    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    // OWNABLE IMPLEMENTATION

    /**
        @dev public getter to check for deployer / owner (Opensea, etc.)
     */
    function owner() external view returns (address) {
        return _deployer;
    }

    // ERC-721 METADATA IMPLEMENTATION
    /**
        @dev compliance with ERC-721 standard (NFT); returns NFT metadata, including SVG-encoded image
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        uint256 info = burnInfo[tokenId];
        //uint256 burned = xenBurned[tokenId];
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "XEN Burn #',
            tokenId.toString(),
            '",',
            '"description": "XENFT: XEN Proof Of Burn",',
            '"image": "',
            "data:image/svg+xml;base64,",
            Base64.encode(BurnMetadata.svgData(tokenId, info, address(xenCrypto))),
            '",',
            '"attributes": ',
            BurnMetadata.attributes(info),
            "}"
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }

    // OVERRIDING OF ERC-721 IMPLEMENTATION
    // ENFORCEMENT OF TRANSFER BLACKOUT PERIOD

    /**
        @dev overrides OZ ERC-721 after transfer hook to allow token enumeration for owner
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        _ownedTokens[from].removeItem(tokenId);
        _ownedTokens[to].addItem(tokenId);
    }

    // IBurnRedeemable IMPLEMENTATION

    /**
        @dev implements IBurnRedeemable interface for burning XEN and completing XENFT minting
     */
    function onTokenBurned(address user, uint256 burned) external {
        require(_tokenId != _NOT_USED, "XENFT: illegal callback state");
        require(msg.sender == address(xenCrypto), "XENFT: illegal callback caller");
        _ownedTokens[user].addItem(_tokenId);
        xenBurned[_tokenId] = burned;
        burnInfo[_tokenId] = _burnInfo(_tokenId, burned);
        _safeMint(user, _tokenId);
        tokenIdCounter++;
        emit Burned(user, burned);
        _tokenId = _NOT_USED;
    }

    // OVERRIDING ERC-721 IMPLEMENTATION TO ALLOW OPENSEA ROYALTIES ENFORCEMENT PROTOCOL

    /**
        @dev implements `setApprovalForAll` with additional approved Operator checking
     */
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    /**
        @dev implements `approve` with additional approved Operator checking
     */
    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    /**
        @dev implements `transferFrom` with additional approved Operator checking
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /**
        @dev implements `safeTransferFrom` with additional approved Operator checking
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
        @dev implements `safeTransferFrom` with additional approved Operator checking
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // SUPPORT FOR ERC2771 META-TRANSACTIONS

    /**
        @dev Implements setting a `Trusted Forwarder` for meta-txs. Settable only once
     */
    function addForwarder(address trustedForwarder) external {
        require(msg.sender == _deployer, "XENFT: not an deployer");
        require(_trustedForwarder == address(0), "XENFT: Forwarder is already set");
        _trustedForwarder = trustedForwarder;
    }

    // SUPPORT FOR ERC2981 ROYALTY INFO

    /**
        @dev Implements getting Royalty Info by supported operators. ROYALTY_BP is expressed in basis points
     */
    function royaltyInfo(uint256, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        receiver = _royaltyReceiver;
        royaltyAmount = (salePrice * ROYALTY_BP) / 10_000;
    }

    // XEN BURN PRIVATE / INTERNAL HELPERS

    /**
        @dev internal burn interface. calculates rarityBits and rarityScore
     */
    function _calcRarity(uint256 tokenId) private view returns (uint256 rarityScore, uint256 rarityBits) {
        bool isPrime = tokenId.isPrime();
        bool isFib = tokenId.isFib();
        bool blockIsPrime = block.number.isPrime();
        bool blockIsFib = block.number.isFib();
        rarityScore += (isPrime ? 500 : 0);
        rarityScore += (blockIsPrime ? 1_000 : 0);
        rarityScore += (isFib ? 5_000 : 0);
        rarityScore += (blockIsFib ? 10_000 : 0);
        rarityBits = BurnInfo.encodeRarityBits(isPrime, isFib, blockIsPrime, blockIsFib);
    }

    /**
        @dev internal burn interface. composes BurnInfo
     */
    function _burnInfo(uint256 tokenId, uint256 amount) private view returns (uint256 info) {
        (uint256 rarityScore, uint256 rarityBits) = _calcRarity(tokenId);
        info = BurnInfo.encodeBurnInfo(block.timestamp, amount / 10 ** 18, rarityScore, rarityBits);
    }

    // PUBLIC GETTERS

    /**
        @dev public getter for tokens owned by address
     */
    function ownedTokens() external view returns (uint256[] memory) {
        return _ownedTokens[_msgSender()];
    }

    // PUBLIC TRANSACTIONAL INTERFACE

    /**
        @dev    public XEN Burn interface
                burns XEN and issues XENFT for the burned amount
     */
    function burn(uint256 amount) public returns (uint256 tokenId) {
        require(_tokenId == _NOT_USED, "XENFT: reentrancy detected");
        require(amount > 0, "XENFT: Illegal amount");
        _tokenId = tokenIdCounter;
        tokenId = tokenIdCounter;
        xenCrypto.burn(_msgSender(), amount);
    }
}
