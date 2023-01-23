// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./DateTime.sol";
import "./FormattedStrings.sol";
import "./BurnSVG.sol";

/**
    @dev Library contains methods to generate on-chain NFT metadata
*/
library BurnMetadata {
    using DateTime for uint256;
    using Strings for uint256;

    // PRIVATE HELPERS

    // The following pure methods returning arrays are workaround to use array constants,
    // not yet available in Solidity

    /**
        @dev private helper to generate SVG gradients
     */
    function _commonCategoryGradients() private pure returns (BurnSVG.Gradient[] memory gradients) {
        BurnSVG.Color[] memory colors = new BurnSVG.Color[](3);
        colors[0] = BurnSVG.Color({h: 1, s: 30, l: 5, a: "1", off: 0});
        colors[1] = BurnSVG.Color({h: 1, s: 45, l: 12, a: "1", off: 50});
        colors[2] = BurnSVG.Color({h: 1, s: 60, l: 36, a: "1", off: 100});
        BurnSVG.Color[] memory colors1 = new BurnSVG.Color[](3);
        colors1[0] = BurnSVG.Color({h: 1, s: 100, l: 50, a: "1", off: 20});
        colors1[1] = BurnSVG.Color({h: 35, s: 100, l: 50, a: "0.6", off: 60});
        colors1[2] = BurnSVG.Color({h: 60, s: 100, l: 50, a: "0.05", off: 90});
        gradients = new BurnSVG.Gradient[](2);
        gradients[0] = BurnSVG.Gradient({colors: colors, id: 0, coords: [uint256(50), 0, 50, 100]});
        gradients[1] = BurnSVG.Gradient({colors: colors1, id: 1, coords: [uint256(50), 0, 50, 100]});
    }

    // PUBLIC INTERFACE

    /**
        @dev public interface to generate SVG image based on XENFT params
     */
    function svgData(uint256 tokenId, address token, uint256 burned) external view returns (bytes memory) {
        string memory symbol = IERC20Metadata(token).symbol();
        BurnSVG.SvgParams memory params = BurnSVG.SvgParams({
            symbol: symbol,
            xenAddress: token,
            tokenId: tokenId,
            xenBurned: burned
        });
        return BurnSVG.image(params, _commonCategoryGradients());
    }

    function _attr1(uint256 burned) private pure returns (bytes memory) {
        return
        abi.encodePacked(
            '{"trait_type":"Burned","value":"',
            (burned / 10 ** 18).toString(),
            '"}'
        );
    }

    /**
        @dev private helper to construct attributes portion of NFT metadata
     */
    function attributes(uint256 burned) external pure returns (bytes memory) {
        return abi.encodePacked("[", _attr1(burned), "]");
    }

    function formattedString(uint256 n) public pure returns (string memory) {
        return FormattedStrings.toFormattedString(n);
    }
}
