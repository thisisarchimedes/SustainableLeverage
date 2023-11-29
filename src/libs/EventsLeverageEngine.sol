// SPDX-License-Identifier: UNLICENSED
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
    event GlobalParameterUpdated(string parameter, uint256 value);
    event FeeCollectorUpdated(address newFeeCollector);
    event MonitorUpdated(address newMonitor);
    event ExpiredVaultUpdated(address newExpiredVault);
    event StrategyLiquidationFeeUpdated(address strategy, uint256 fee);
    event PositionOpened(
        uint256 indexed nftId,
        address indexed user,
        address indexed strategy,
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        uint256 positionExpireBlock,
        uint256 sharesReceived,
        uint256 liquidationBuffer
    );
    event PositionClosed(
        uint256 indexed nftId,
        address indexed user,
        address indexed strategy,
        uint256 receivedAmount,
        uint256 wbtcDebtAmount,
        uint256 exitFee
    );
    event OracleSet(address token, IOracle oracle);
}
