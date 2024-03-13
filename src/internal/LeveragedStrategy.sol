// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { IERC20Detailed } from "src/interfaces/IERC20Detailed.sol";
import { Constants } from "src/libs/Constants.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";

import { PositionLedger, PositionState } from "src/internal/PositionLedger.sol";
import { OracleManager } from "src/internal/OracleManager.sol";
import { IMultiPoolStrategy } from "src/interfaces/IMultiPoolStrategy.sol";
import { ProtocolParameters } from "src/internal/ProtocolParameters.sol";

/// @title StrategyManager Contract
/// @notice Only supports WBTC as collateral and borrowing asset
contract LeveragedStrategy is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;
    using Constants for *;

    IERC20 internal constant WBTC = IERC20(Constants.WBTC_ADDRESS);
    uint256 internal constant WBTC_DECIMALS = 8;

    struct StrategyConfig {
        uint256 quota;
        uint256 positionLifetime;
        uint256 maximumMultiplier;
        uint256 liquidationBuffer;
        uint256 liquidationFee;
    }

    mapping(address => StrategyConfig) internal strategyConfig;
    PositionLedger public positionLedger;
    OracleManager public oracleManager;
    ProtocolParameters public protocolParameters;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionOpener);

        positionLedger = PositionLedger(dependencies.positionLedger);
        oracleManager = OracleManager(dependencies.oracleManager);
        protocolParameters = ProtocolParameters(dependencies.protocolParameters);
    }

    function setStrategyConfig(
        address strategy,
        StrategyConfig calldata config
    )
        external
        onlyRole(ProtocolRoles.ADMIN_ROLE)
    {
        uint8 minPositionLifetime = protocolParameters.getMinPositionDurationInBlocks();
        if (config.positionLifetime < minPositionLifetime) {
            revert ErrorsLeverageEngine.PositionLifetimeTooShort();
        }
        strategyConfig[strategy] = config;

        emit EventsLeverageEngine.StrategyConfigUpdated(
            strategy,
            config.quota,
            config.positionLifetime,
            config.maximumMultiplier,
            config.liquidationBuffer,
            config.liquidationFee
        );
    }

    function getStrategyConfig(address strategy) public view returns (StrategyConfig memory) {
        return strategyConfig[strategy];
    }

    function removeStrategy(address strategy) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        strategyConfig[strategy].quota = 0;

        emit EventsLeverageEngine.StrategyRemoved(strategy);
    }

    function setLiquidationFee(address strategy, uint256 fee) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        strategyConfig[strategy].liquidationFee = fee;

        emit EventsLeverageEngine.StrategyLiquidationFeeUpdated(strategy, fee);
    }

    function reduceQuotaBy(address strategy, uint256 amount) external onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE) {
        if (strategyConfig[strategy].quota < amount) {
            revert ErrorsLeverageEngine.ExceedBorrowQuota();
        }

        strategyConfig[strategy].quota -= amount;
    }

    function getLiquidationFee(address strategy) external view returns (uint256) {
        return strategyConfig[strategy].liquidationFee;
    }

    function setQuota(address strategy, uint256 quota) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        strategyConfig[strategy].quota = quota;
    }

    function getQuota(address strategy) external view returns (uint256) {
        return strategyConfig[strategy].quota;
    }

    function getPositionLifetime(address strategy) external view returns (uint256) {
        return strategyConfig[strategy].positionLifetime;
    }

    function getLiquidationBuffer(address strategy) external view returns (uint256) {
        return strategyConfig[strategy].liquidationBuffer;
    }

    function getMaximumMultiplier(address strategy) external view returns (uint256) {
        return strategyConfig[strategy].maximumMultiplier;
    }

    function isCollateralToBorrowRatioAllowed(
        address strategy,
        uint256 collateralAmount,
        uint256 borrowedAmount
    )
        external
        view
        returns (bool)
    {
        if (collateralAmount * strategyConfig[strategy].maximumMultiplier / 10 ** WBTC_DECIMALS < borrowedAmount) {
            return false;
        }

        return true;
    }

    function isPositionLiquidatableEstimation(uint256 nftId) external view returns (bool) {
        if (positionLedger.getPositionState(nftId) != PositionState.LIVE) {
            revert ErrorsLeverageEngine.PositionNotLive();
        }

        address strategy = positionLedger.getStrategyAddress(nftId);
        uint256 positionValue = previewPositionValueInWBTC(nftId);
        uint256 wbtcDebtAmount = positionLedger.getDebtAmount(nftId);

        return isPositionLiquidatable(strategy, positionValue, wbtcDebtAmount);
    }

    function isPositionLiquidatable(address strategy, uint256 positionValue, uint256 debt) public view returns (bool) {
        if (positionValue <= debt * strategyConfig[strategy].liquidationBuffer / 10 ** WBTC_DECIMALS) {
            return true;
        }

        return false;
    }

    function previewPositionValueInWBTC(uint256 nftId) public view returns (uint256) {
        uint256 strategyShares = positionLedger.getStrategyShares(nftId);
        address strategyAddress = positionLedger.getStrategyAddress(nftId);

        uint256 strategyValueTokenEstimatedAmount = IMultiPoolStrategy(strategyAddress).convertToAssets(strategyShares);

        address strategyValueTokenAddress = IMultiPoolStrategy(strategyAddress).asset();

        return getWBTCValueFromTokenAmount(strategyValueTokenAddress, strategyValueTokenEstimatedAmount);
    }

    function getWBTCValueFromTokenAmount(address token, uint256 amount) public view returns (uint256) {
        uint256 tokenPriceInUSD = oracleManager.getLatestTokenPriceInUSD(token);
        uint256 wbtcPriceInUSD = oracleManager.getLatestTokenPriceInUSD(address(WBTC));

        uint256 tokenValueInWBTCUnadjustedDecimals = ((amount * uint256(tokenPriceInUSD)) / (uint256(wbtcPriceInUSD)));

        return adjustDecimalsToWBTCDecimals(token, tokenValueInWBTCUnadjustedDecimals);
    }

    function adjustDecimalsToWBTCDecimals(
        address fromToken,
        uint256 amountUnadjustedDecimals
    )
        internal
        view
        returns (uint256)
    {
        uint8 fromTokenDecimals = IERC20Detailed(fromToken).decimals();

        uint8 fromTokenOracleDecimals = oracleManager.getUSDOracleDecimals(fromToken);
        uint8 wbtcOracleDecimals = oracleManager.getUSDOracleDecimals(address(WBTC));

        uint256 fromDec = fromTokenDecimals + fromTokenOracleDecimals;
        uint256 toDec = wbtcOracleDecimals + WBTC_DECIMALS;

        if (fromDec > toDec) {
            return amountUnadjustedDecimals / 10 ** (fromDec - toDec);
        } else {
            return amountUnadjustedDecimals * 10 ** (toDec - fromDec);
        }
    }

    function getTokenValueFromWBTCAmount(address token, uint256 wbtcAmount) public view returns (uint256) {
        uint256 tokenPriceInUSD = oracleManager.getLatestTokenPriceInUSD(token);
        uint256 wbtcPriceInUSD = oracleManager.getLatestTokenPriceInUSD(address(WBTC));

        uint256 tokenAmountUnadjustedDecimals = wbtcAmount * wbtcPriceInUSD / tokenPriceInUSD;

        return adjustDecimalsToTokenDecimals(token, tokenAmountUnadjustedDecimals);
    }

    function adjustDecimalsToTokenDecimals(
        address fromToken,
        uint256 amountUnadjustedDecimals
    )
        internal
        view
        returns (uint256)
    {
        uint8 tokenDecimals = IERC20Detailed(fromToken).decimals();
        uint8 tokenOracleDecimals = oracleManager.getUSDOracleDecimals(fromToken);
        uint8 wbtcOracleDecimals = oracleManager.getUSDOracleDecimals(address(WBTC));

        uint256 fromDec = WBTC_DECIMALS + wbtcOracleDecimals - tokenOracleDecimals;

        if (fromDec > tokenDecimals) {
            return amountUnadjustedDecimals / 10 ** (fromDec - tokenDecimals);
        } else {
            return amountUnadjustedDecimals * 10 ** (tokenDecimals - fromDec);
        }
    }

    function getEstimateSharesForWBTCDeposit(
        address strategy,
        uint256 wbtcDepositAmount
    )
        external
        view
        returns (uint256)
    {
        address token = getStrategyValueAsset(strategy);

        uint256 depositAmount = getTokenValueFromWBTCAmount(token, wbtcDepositAmount);

        return IMultiPoolStrategy(strategy).previewDeposit(depositAmount);
    }

    function getStrategyValueAsset(address strategy) public view returns (address) {
        return IMultiPoolStrategy(strategy).asset();
    }
}
