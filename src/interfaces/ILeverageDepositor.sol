// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

interface ILeverageDepositor {
    function deposit(
        address strategy,
        address strategyAsset,
        uint256 amount
    )
        external
        returns (uint256 receivedShares);
}
