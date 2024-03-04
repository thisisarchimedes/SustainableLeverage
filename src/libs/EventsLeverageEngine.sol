// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IOracle } from "src/interfaces/IOracle.sol";

library EventsLeverageEngine {
    event StrategyConfigUpdated(
        address indexed strategy,
        uint256 quota,
        uint256 positionLifetime,
        uint256 maximumMultiplier,
        uint256 liquidationBuffer,
        uint256 liquidationFee
    );
    event StrategyRemoved(address indexed strategy);
    event StrategyLiquidationFeeUpdated(address strategy, uint256 fee);

    event FeeCollectorUpdated(address newFeeCollector);
    event MonitorUpdated(address newMonitor);
    event ExpiredVaultUpdated(address newExpiredVault);
    event ETHOracleSet(address token, IOracle oracle);
    event USDOracleSet(address token, IOracle oracle);
    event ExitFeeUpdated(uint256 fee);

    event PositionOpened(
        uint256 indexed nftId,
        address indexed user,
        address indexed strategy,
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        uint256 positionExpireBlock,
        uint256 sharesReceived
    );
    event PositionClosed(
        uint256 indexed nftId, 
        address indexed user, 
        address indexed strategy,
        uint256 receivedAmount, 
        uint256 wbtcDebtAmount
    );
    event PositionLiquidated(
        uint256 indexed nftId,
        address indexed strategy,
        uint256 wbtcDebtPaid,
        uint256 claimableAmount,
        uint256 liquidationFee
    );

    event PositionExpired(
        uint256 indexed nftId, 
        address indexed strategy, 
        uint256 wbtcDebtPaid,
        uint256 claimableAmount
    );

    event Deposit(address indexed depositor, uint256 amount);
    event Claim(address indexed claimer, uint256 indexed nftId, uint256 amount);
    event Repay(uint256 indexed nftId, uint256 amount);
}
