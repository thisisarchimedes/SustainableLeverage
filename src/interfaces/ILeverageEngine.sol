// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./IERC20Detailed.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "../PositionLedgerLib.sol";
import { IWBTCVault } from "./IWBTCVault.sol";
import { ILeverageDepositor } from "./ILeverageDepositor.sol";
import { PositionToken } from "../PositionToken.sol";
import { SwapAdapter } from "../SwapAdapter.sol";
import { IMultiPoolStrategy } from "./IMultiPoolStrategy.sol";
import { AggregatorV3Interface } from "./AggregatorV3Interface.sol";

interface ILeverageEngine {
    /// @notice Strategy configurations structure
    /// @param quota WBTC Quota for the strategy
    /// @param positionLifetime Lifetime of a position in blocks
    /// @param maximumMultiplier Maximum borrowing power multiplier
    /// @param liquidationBuffer Threshold for liquidation
    struct StrategyConfig {
        uint256 quota;
        uint256 positionLifetime;
        uint256 maximumMultiplier;
        uint256 liquidationBuffer;
    }

    enum StrategyConfigUpdate {
        QUOTA,
        POSITION_LIFETIME,
        MAXIMUM_MULTIPLIER,
        LIQUIDATION_BUFFER
    }

    ///////////// Admin functions /////////////

    function setStrategyConfig(
        address strategy,
        uint256 _quota,
        uint256 _positionLifetime,
        uint256 _maximumMultiplier,
        uint256 _liquidationBuffer
    )
        external;

    function removeStrategy(address strategy) external;

    function updateStrategyConfig(address strategy, uint256 value, StrategyConfigUpdate configType) external;

    function setOracle(address token, address oracle) external;

    function changeSwapAdapter(address _swapAdapter) external;

    function setLiquidationFee(uint256 fee) external;

    function setExitFee(uint256 fee) external;

    function setFeeCollector(address collector) external;

    ///////////// User functions /////////////

    function openPosition(
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        address strategy,
        uint256 minStrategyShares,
        SwapAdapter.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        external;

    ///////////// View functions /////////////

    function previewOpenPosition(
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        address strategy,
        uint256 minimumExpected
    )
        external
        view
        returns (uint256 estimatedShares);

    function closePosition(
        uint256 nftID,
        uint256 minWBTC,
        SwapAdapter.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        external;

    function closeExpiredPosition(uint256 nftID, address sender) external;

    function getStrategyConfig(address strategy) external view returns (StrategyConfig memory);

    function getPosition(uint256 nftID) external view returns (PositionLedgerLib.LedgerEntry memory);
}
