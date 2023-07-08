// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./DateTime.sol";
import "./FormattedStrings.sol";
import "./BurnInfo.sol";
import "./BurnSVG.sol";

/**
    @dev Library contains methods to generate on-chain NFT metadata
*/
library BurnMetadata {
    using DateTime for uint256;
    using BurnInfo for uint256;
    using Strings for uint256;

    // PRIVATE HELPERS

    // The following pure methods returning arrays are workaround to use array constants,
    // not yet available in Solidity

    /**
        @dev private helper to generate SVG gradients
     */
    function _gradients(uint256 rarityScore) private pure returns (BurnSVG.Gradient[] memory gradients) {
        bool isRare = rarityScore > 0;
        BurnSVG.Color[] memory colors = new BurnSVG.Color[](3);
        colors[0] = BurnSVG.Color({h: isRare ? 201 : 1, s: 30, l: 5, a: "1", off: 0});
        colors[1] = BurnSVG.Color({h: isRare ? 241 : 1, s: 45, l: 12, a: "1", off: 50});
        colors[2] = BurnSVG.Color({h: isRare ? 281 : 1, s: 60, l: 36, a: "1", off: 100});
        BurnSVG.Color[] memory colors1 = new BurnSVG.Color[](3);
        colors1[0] = BurnSVG.Color({h: isRare ? 201: 1, s: 100, l: 50, a: "1", off: 20});
        colors1[1] = BurnSVG.Color({h: isRare ? 280: 35, s: 100, l: 50, a: "0.6", off: 60});
        colors1[2] = BurnSVG.Color({h: 60, s: 100, l: 50, a: "0.05", off: 90});
        gradients = new BurnSVG.Gradient[](2);
        gradients[0] = BurnSVG.Gradient({colors: colors, id: 0, coords: [uint256(50), 0, 50, 100]});
        gradients[1] = BurnSVG.Gradient({colors: colors1, id: 1, coords: [uint256(50), 0, 50, 100]});
    }

    /**
        @dev private helper to calculate medata art object position and size
     */
    function _scalePos(uint256 amount) private pure returns (BurnSVG.ScalePos memory scalePos) {
        if (amount < 10_000)
            return BurnSVG.ScalePos({ yPos: 526, scale1: '1.3', scale2: '1.0' });
        if (amount < 10_000_000)
            return BurnSVG.ScalePos({ yPos: 536, scale1: '1.7', scale2: '1.4' });
        if (amount < 10_000_000_000)
            return BurnSVG.ScalePos({ yPos: 546, scale1: '2.1', scale2: '1.8' });
        if (amount < 10_000_000_000_000)
            return BurnSVG.ScalePos({ yPos: 556, scale1: '2.5', scale2: '2.2' });
        return BurnSVG.ScalePos({ yPos: 566, scale1: '2.9', scale2: '2.6' });
    }

    /**
        @dev private helper to generate attribute objects for metadata props
     */
    function _attr1(uint256 burnTs, uint256 amount, uint256 rarityScore) private pure returns (bytes memory) {
        return
        abi.encodePacked(
            '{"trait_type":"Burned XEN","value":"',
            amount.toString(),
            '"},'
            '{"trait_type":"DateTime Burned","value":"',
            burnTs.asString(),
            '"},'
            '{"trait_type":"Rarity Score","value":"',
            rarityScore.toString(),
            '"}'
        );
    }


    // PUBLIC INTERFACE

    /**
        @dev public interface to generate SVG image based on XENFT params
     */
    function svgData(uint256 tokenId, uint256 info, address token) external view returns (bytes memory) {
        string memory symbol = IERC20Metadata(token).symbol();
        BurnSVG.SvgParams memory params = BurnSVG.SvgParams({
            symbol: symbol,
            xenAddress: token,
            tokenId: tokenId,
            xenBurned: info.getAmount(),
            rarityScore: info.getRarityScore()
        });
        return BurnSVG.image(params, _gradients(info.getRarityScore()), _scalePos(info.getAmount()));
    }

    /**
        @dev private helper to construct attributes portion of NFT metadata
     */
    function attributes(uint256 burnInfo) external pure returns (bytes memory) {
        (uint256 burnTs, uint256 amount, uint256 rarityScore, ) = BurnInfo.decodeBurnInfo(burnInfo);
        return abi.encodePacked("[", _attr1(burnTs, amount, rarityScore), "]");
    }

    function formattedString(uint256 n) public pure returns (string memory) {
        return FormattedStrings.toFormattedString(n);
    }
}
