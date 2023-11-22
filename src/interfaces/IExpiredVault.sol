// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

interface IExpiredVault {
    function deposit(uint256 amount) external;
    function claim(uint256 nftID) external;
}