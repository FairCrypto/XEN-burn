// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./DateTime.sol";
import "./FormattedStrings.sol";

/*
    @dev        Library to create SVG image for XENFT metadata
    @dependency depends on DataTime.sol and StringData.sol libraries
 */
library BurnSVG {
    // Type to encode all data params for SVG image generation
    struct SvgParams {
        string symbol;
        address xenAddress;
        uint256 tokenId;
        uint256 xenBurned;
        uint256 rarityScore;
    }

    // Type to encode SVG gradient stop color on HSL color scale
    struct Color {
        uint256 h;
        uint256 s;
        uint256 l;
        string a;
        uint256 off;
    }

    // Type to encode SVG gradient
    struct Gradient {
        Color[] colors;
        uint256 id;
        uint256[4] coords;
    }

    struct ScalePos {
        uint256 yPos;
        bytes scale1;
        bytes scale2;
    }

    using DateTime for uint256;
    using Strings for uint256;
    using FormattedStrings for uint256;
    using Strings for address;

    string private constant _STYLE =
        "<style> "
        ".base {fill: #ededed;font-family:Montserrat,arial,sans-serif;font-size:30px;font-weight:400;} "
        ".series {text-transform: uppercase} "
        ".logo {font-size:200px;font-weight:100;} "
        ".meta {font-size:12px;} "
        ".small {font-size:8px;} "
        ".burn {font-weight:500;font-size:16px;} }"
        "</style>";

    string private constant _BURN =
        "<g>"
        "<path "
        'stroke="none" '
        'fill="url(#g1)" '
        'transform="translate(170,566), scale(2.8)" '
        'd="M -14 0 c -13 -13 -18 -26 -13 -37 c 8 -17 15 -24 11 -45 c 0 0 15 -2 27 28 c 0 0 10 -1 8 -18 c 3 -1 35 43 1 72 z"/>'
        "<path "
        'stroke="none" '
        'fill="url(#g1)" '
        'transform="translate(170,566), scale(2.5)" '
        'd="M -10 0 c -13 -13 -18 -26 -9 -39 c 8 -17 14 -20 9 -34 c 10 6 13 13 19 31 c 9 -2 13 -7 14 -17 c 3 -1 15 37 -7 59 z"/>'
        "</g>";

    string private constant _LOGO =
        '<path fill="#ededed" '
        'd="M122.7,227.1 l-4.8,0l55.8,-74l0,3.2l-51.8,-69.2l5,0l48.8,65.4l-1.2,0l48.8,-65.4l4.8,0l-51.2,68.4l0,-1.6l55.2,73.2l-5,0l-52.8,-70.2l1.2,0l-52.8,70.2z" '
        'vector-effect="non-scaling-stroke" />';

    /**
        @dev internal helper to create HSL-encoded color prop for SVG tags
     */
    function colorHSL(Color memory c) internal pure returns (bytes memory) {
        return abi.encodePacked("hsl(", c.h.toString(), ", ", c.s.toString(), "%, ", c.l.toString(), "%)");
    }

    /**
        @dev internal helper to create `stop` SVG tag
     */
    function colorStop(Color memory c) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                '<stop stop-color="',
                colorHSL(c),
                '" stop-opacity="',
                c.a,
                '" offset="',
                c.off.toString(),
                '%"/>'
            );
    }

    /**
        @dev internal helper to encode position for `Gradient` SVG tag
     */
    function pos(uint256[4] memory coords) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                'x1="',
                coords[0].toString(),
                '%" '
                'y1="',
                coords[1].toString(),
                '%" '
                'x2="',
                coords[2].toString(),
                '%" '
                'y2="',
                coords[3].toString(),
                '%" '
            );
    }

    /**
        @dev internal helper to create `Gradient` SVG tag
     */
    function linearGradient(
        Color[] memory colors,
        uint256 id,
        uint256[4] memory coords
    ) internal pure returns (bytes memory) {
        string memory stops = "";
        for (uint256 i = 0; i < colors.length; i++) {
            if (colors[i].h != 0) {
                stops = string.concat(stops, string(colorStop(colors[i])));
            }
        }
        return
            abi.encodePacked(
                "<linearGradient  ",
                pos(coords),
                'id="g',
                id.toString(),
                '">',
                stops,
                "</linearGradient>"
            );
    }

    /**
        @dev internal helper to create `Defs` SVG tag
     */
    function defs(Gradient[] memory grads) internal pure returns (bytes memory) {
        string memory res = '';
        for (uint i = 0; i < grads.length; i++) {
            res = string.concat(
                res,
                string(linearGradient(grads[i].colors, i, grads[i].coords))
            );
        }
        return abi.encodePacked("<defs>", res, "</defs>");
    }

    /**
        @dev internal helper to create `Rect` SVG tag
     */
    function rect(uint256 id) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                "<rect "
                'width="100%" '
                'height="100%" '
                'fill="url(#g',
                id.toString(),
                ')" '
                'rx="10px" '
                'ry="10px" '
                'stroke-linejoin="round" '
                "/>"
            );
    }

    /**
        @dev internal helper to create border `Rect` SVG tag
     */
    function border() internal pure returns (string memory) {
        return
            "<rect "
            'width="94%" '
            'height="96%" '
            'fill="transparent" '
            'rx="10px" '
            'ry="10px" '
            'stroke-linejoin="round" '
            'x="3%" '
            'y="2%" '
            'stroke-dasharray="1,6" '
            'stroke="white" '
            "/>";
    }

    /**
        @dev internal helper to create group `G` SVG tag
     */
    function g(uint256 gradientsCount) internal pure returns (bytes memory) {
        string memory background = "";
        for (uint256 i = 0; i < gradientsCount; i++) {
            background = string.concat(background, string(rect(i)));
        }
        return abi.encodePacked("<g>", background, border(), "</g>");
    }

    /**
        @dev internal helper to create flame pattern
     */
    function burn(bytes memory scale1, bytes memory scale2, uint256 yPos) internal pure returns (bytes memory) {
        return abi.encodePacked(
            "<g>"
            "<path "
            'stroke="none" '
            'fill="url(#g1)" '
            'transform="translate(170,',
            yPos.toString(),
            '), scale(',
            scale1,
            ')" '
            'd="M -14 0 c -13 -13 -18 -26 -13 -37 c 8 -17 15 -24 11 -45 c 0 0 15 -2 27 28 c 0 0 10 -1 8 -18 c 3 -1 35 43 1 72 z"/>'
            "<path "
            'stroke="none" '
            'fill="url(#g1)" '
            'transform="translate(170,',
            yPos.toString(),
            '), scale(',
            scale2,
            ')" '
            'd="M -10 0 c -13 -13 -18 -26 -9 -39 c 8 -17 14 -20 9 -34 c 10 6 13 13 19 31 c 9 -2 13 -7 14 -17 c 3 -1 15 37 -7 59 z"/>'
            "</g>"
        );
    }

    /**
        @dev internal helper to create `Text` SVG tag with XEN Crypto contract data
     */
    function contractData(string memory symbol, address xenAddress) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                "<text "
                'x="50%" '
                'y="5%" '
                'class="base small" '
                'dominant-baseline="middle" '
                'text-anchor="middle">',
                symbol,
                unicode"・",
                xenAddress.toHexString(),
                "</text>"
            );
    }

    /**
        @dev internal helper to create 1st part of metadata section of SVG
     */
    function meta1(uint256 tokenId, uint256 xenBurned, uint256 rarityScore) internal pure returns (bytes memory) {
        bytes memory part1 = abi.encodePacked(
            "<text "
            'x="50%" '
            'y="50%" '
            'class="base " '
            'dominant-baseline="middle" '
            'text-anchor="middle">'
            "XEN CRYPTO"
            "</text>"
            "<text "
            'x="50%" '
            'y="56%" '
            'class="base burn" '
            'text-anchor="middle" '
            'dominant-baseline="middle"> ',
            xenBurned > 0 ? string.concat(xenBurned.toFormattedString(), " X") : "",
            "</text>"
            "<text "
            'x="18%" '
            'y="62%" '
            'class="base meta" '
            'dominant-baseline="middle"> '
            "#",
            tokenId.toString(),
            "</text>"
            "<text "
            'x="82%" '
            'y="62%" '
            'class="base meta series" '
            'dominant-baseline="middle" '
            'text-anchor="end" >'
            'BURN'
            "</text>"
        );
        bytes memory part2 = abi.encodePacked(
            "<text "
            'x="18%" '
            'y="68%" '
            'class="base meta" '
            'dominant-baseline="middle"> '
            "Rarity",
            "</text>"
            "<text "
            'x="82%" '
            'y="68%" '
            'class="base meta " '
            'dominant-baseline="middle" '
            'text-anchor="end" >',
            rarityScore.toString(),
            "</text>"
        );
        return abi.encodePacked(part1, part2);
    }

    /**
        @dev main internal helper to create SVG file representing XENFT
     */
    function image(
        SvgParams memory params,
        Gradient[] memory gradients,
        ScalePos memory scalePos
    ) internal pure returns (bytes memory) {
        bytes memory mark = burn(scalePos.scale1, scalePos.scale2, scalePos.yPos);
        bytes memory graphics = abi.encodePacked(defs(gradients), _STYLE, g(1), _LOGO, mark);
        bytes memory metadata = abi.encodePacked(
            contractData(params.symbol, params.xenAddress),
            meta1(params.tokenId, params.xenBurned, params.rarityScore)
        );
        return
            abi.encodePacked(
                "<svg "
                'xmlns="http://www.w3.org/2000/svg" '
                'preserveAspectRatio="xMinYMin meet" '
                'viewBox="0 0 350 566">',
                graphics,
                metadata,
                "</svg>"
            );
    }
}
