// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IXENBurner {
    function xenBurned(uint256 tokenId) external returns (uint256 amount);
}
