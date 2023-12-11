// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

interface ILeverageDepositor {

    function allowStrategyWithDepositor(address strategy) external;
    function denyStrategyWithDepositor(address strategy) external;

    function deposit(address strategy, uint256 amount) external returns (uint256);
    function redeem(address strategy, uint256 strategyShares) external returns (uint256);
}
