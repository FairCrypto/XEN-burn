// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// mapping: NFT tokenId => BurnInfo (used in tokenURI generation + other contracts)
// BurnInfo encoded as:
//      ---- (uint16)
//      | burnTs (uint64)
//      | amount (uint128)
//      | ---- (uint16)
//      | rarityScore (uint16)
//      | rarityBits (uint16):
//          [15] tokenIdIsPrime
//          [14] tokenIdIsFib
//          [14] blockIdIsPrime
//          [13] blockIdIsFib
//          [0-13] ...
library BurnInfo {
    /**
        @dev helper to convert Bool to U256 type and make compiler happy
     */
    function toU256(bool x) internal pure returns (uint256 r) {
        assembly {
            r := x
        }
    }

    /**
        @dev encodes BurnInfo record from its props
     */
    function encodeBurnInfo(
        uint256 burnTs,
        uint256 amount,
        uint256 rarityScore,
        uint256 rarityBits
    ) public pure returns (uint256 info) {
        info = info | (rarityBits & 0xFFFF);
        info = info | ((rarityScore & 0xFFFF) << 16);
        info = info | ((amount & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) << 48);
        info = info | ((burnTs & 0xFFFFFFFFFFFFFFFF) << 176);
    }

    /**
        @dev decodes BurnInfo record and extracts all of its props
     */
    function decodeBurnInfo(uint256 info)
        public
        pure
        returns (uint256 burnTs, uint256 amount, uint256 rarityScore, uint256 rarityBits)
    {
        burnTs = uint64(info >> 176);
        amount = uint128(info >> 48);
        rarityScore = uint16(info >> 16);
        rarityBits = uint16(info);
    }

    /**
        @dev extracts `burnTs` prop from encoded BurnInfo
     */
    function getBurnTs(uint256 info) public pure returns (uint256 burnTs) {
        (burnTs, , , ) = decodeBurnInfo(info);
    }

    /**
        @dev extracts `amount` prop from encoded BurnInfo
     */
    function getAmount(uint256 info) public pure returns (uint256 amount) {
        (, amount, , ) = decodeBurnInfo(info);
    }

    /**
        @dev extracts `rarityScore` prop from encoded BurnInfo
     */
    function getRarityScore(uint256 info) public pure returns (uint256 rarityScore) {
        (, , rarityScore, ) = decodeBurnInfo(info);
    }

    /**
        @dev extracts `rarityBits` prop from encoded BurnInfo
     */
    function getRarityBits(uint256 info) public pure returns (uint256 rarityBits) {
        (, , , rarityBits) = decodeBurnInfo(info);
    }

    /**
        @dev decodes boolean flags from `rarityBits` prop
     */
    function decodeRarityBits(
        uint256 rarityBits
    ) public pure returns (bool isPrime, bool isFib, bool blockIsPrime, bool blockIsFib) {
        isPrime = rarityBits & 0x0008 > 0;
        isFib = rarityBits & 0x0004 > 0;
        blockIsPrime = rarityBits & 0x0002 > 0;
        blockIsFib = rarityBits & 0x0001 > 0;
    }

    /**
        @dev encodes boolean flags to `rarityBits` prop
     */
    function encodeRarityBits(
        bool isPrime,
        bool isFib,
        bool blockIsPrime,
        bool blockIsFib
    ) public pure returns (uint256 rarityBits) {
        rarityBits = rarityBits | ((toU256(isPrime) << 3) & 0xFFFF);
        rarityBits = rarityBits | ((toU256(isFib) << 2) & 0xFFFF);
        rarityBits = rarityBits | ((toU256(blockIsPrime) << 1) & 0xFFFF);
        rarityBits = rarityBits | ((toU256(blockIsFib)) & 0xFFFF);
    }

    /**
        @dev extracts `rarityBits` prop from encoded BurnInfo
     */
    function getRarityBitsDecoded(
        uint256 info
    ) public pure returns (bool isPrime, bool isFib, bool blockIsPrime, bool blockIsFib) {
        (, , , uint256 rarityBits) = decodeBurnInfo(info);
        (isPrime, isFib, blockIsPrime, blockIsFib) = decodeRarityBits(rarityBits);
    }
}
