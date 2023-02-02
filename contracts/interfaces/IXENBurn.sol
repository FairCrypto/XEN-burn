// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IXENBurn {
    event Burned(address indexed user, uint256 amount);

    function burnXen(uint256 amount) external returns (uint256);
}
