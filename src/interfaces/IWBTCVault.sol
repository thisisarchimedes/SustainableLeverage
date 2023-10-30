// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

interface IWBTCVault {
    function borrow(uint256) external;
    function repay(uint256, uint256) external;
}
