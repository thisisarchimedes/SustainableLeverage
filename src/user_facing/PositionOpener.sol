// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { IERC20 } from "src/interfaces/IERC20Detailed.sol";
import { IWBTCVault } from "src/interfaces/IWBTCVault.sol";
import { ILeverageDepositor } from "src/interfaces/ILeverageDepositor.sol";
import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";

import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";
import { OpenPositionParams } from "src/libs/PositionCallParams.sol";

import { PositionToken } from "src/user_facing/PositionToken.sol";

import { SwapManager } from "src/internal/SwapManager.sol";
import { Constants } from "src/libs/Constants.sol";

import { LeveragedStrategy } from "src/internal/LeveragedStrategy.sol";
import { ProtocolParameters } from "src/internal/ProtocolParameters.sol";
import { OracleManager } from "src/internal/OracleManager.sol";
import { PositionLedger, LedgerEntry } from "src/internal/PositionLedger.sol";

/// @title PositionManager Contract
/// @notice Supports only WBTC tokens for now
contract PositionOpener is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;
    using Constants for *;

    uint256 internal constant BASE_DENOMINATOR = 10_000;
    uint8 internal constant WBTC_DECIMALS = 8;
    IERC20 internal constant WBTC = IERC20(Constants.WBTC_ADDRESS);

    IWBTCVault internal wbtcVault;
    PositionToken internal positionToken;
    ILeverageDepositor internal leverageDepositor;
    SwapManager internal swapManager;
    LeveragedStrategy internal leveragedStrategy;
    ProtocolParameters internal protocolParameters;
    OracleManager internal oracleManager;
    PositionLedger internal positionLedger;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ProtocolRoles.ADMIN_ROLE, ProtocolRoles.ADMIN_ROLE);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        leverageDepositor = ILeverageDepositor(dependencies.leverageDepositor);
        positionToken = PositionToken(dependencies.positionToken);
        swapManager = SwapManager(dependencies.swapManager);
        wbtcVault = IWBTCVault(dependencies.wbtcVault);
        leveragedStrategy = LeveragedStrategy(dependencies.leveragedStrategy);
        protocolParameters = ProtocolParameters(dependencies.protocolParameters);
        oracleManager = OracleManager(dependencies.oracleManager);
        positionLedger = PositionLedger(dependencies.positionLedger);
    }

    function openPosition(OpenPositionParams calldata params) external returns (uint256) {
        if (
            leveragedStrategy.isCollateralToBorrowRatioAllowed(
                params.strategy, params.collateralAmount, params.wbtcToBorrow
            ) == false
        ) {
            revert ErrorsLeverageEngine.ExceedBorrowLimit();
        }

        leveragedStrategy.reduceQuotaBy(params.strategy, params.wbtcToBorrow);
        uint256 receivedTokenAmount;
        address strategyAsset = leveragedStrategy.getStrategyValueAsset(params.strategy);
        if (strategyAsset == address(WBTC)) {
            receivedTokenAmount = params.collateralAmount + params.wbtcToBorrow;
            sendWbtcToLeverageDepositor(receivedTokenAmount);
        } else {
            ISwapAdapter swapAdapter = swapManager.getSwapAdapterForRoute(params.swapRoute);

            sendWbtcToSwapAdapter(address(swapAdapter), params);

            receivedTokenAmount = swapWbtcToStrategyToken(swapAdapter, params);
            if (isSwapReturnedEnoughTokens(params, receivedTokenAmount) == false) {
                revert ErrorsLeverageEngine.NotEnoughTokensReceived();
            }
        }

        uint256 sharesReceived = leverageDepositor.deposit(params.strategy, receivedTokenAmount);
        if (sharesReceived < params.minStrategyShares) {
            revert ErrorsLeverageEngine.LessThanMinimumShares();
        }

        uint256 nftId = createLedgerEntryAndPositionToken(params, sharesReceived);

        emit EventsLeverageEngine.PositionOpened(
            nftId,
            msg.sender,
            params.strategy,
            params.collateralAmount,
            params.wbtcToBorrow,
            block.number + leveragedStrategy.getPositionLifetimeInBlocks(params.strategy),
            sharesReceived
        );

        return nftId;
    }

    function sendWbtcToSwapAdapter(address swapAdapter, OpenPositionParams calldata params) internal {
        wbtcVault.borrowAmountTo(params.wbtcToBorrow, swapAdapter);
        WBTC.safeTransferFrom(msg.sender, swapAdapter, params.collateralAmount);
    }

    function sendWbtcToLeverageDepositor(OpenPositionParams calldata params) internal {
        wbtcVault.borrowAmountTo(params.wbtcToBorrow, address(leverageDepositor));
        WBTC.safeTransferFrom(msg.sender, address(leverageDepositor), params.collateralAmount);
    }

    function swapWbtcToStrategyToken(
        ISwapAdapter swapAdapter,
        OpenPositionParams calldata params
    )
        internal
        returns (uint256)
    {
        address strategyUnderlyingToken = leveragedStrategy.getStrategyValueAsset(params.strategy);
        ISwapAdapter.SwapWbtcParams memory swapParams = ISwapAdapter.SwapWbtcParams({
            otherToken: IERC20(strategyUnderlyingToken),
            fromAmount: params.collateralAmount + params.wbtcToBorrow,
            payload: params.swapData,
            recipient: address(leverageDepositor)
        });

        return swapAdapter.swapFromWbtc(swapParams);
    }

    function isSwapReturnedEnoughTokens(
        OpenPositionParams calldata params,
        uint256 receivedTokenAmount
    )
        internal
        view
        returns (bool)
    {
        address strategyUnderlyingToken = leveragedStrategy.getStrategyValueAsset(params.strategy);
        uint256 receivedTokensInWbtc =
            leveragedStrategy.getWBTCValueFromTokenAmount(strategyUnderlyingToken, receivedTokenAmount);

        return !leveragedStrategy.isPositionLiquidatable(params.strategy, receivedTokensInWbtc, params.wbtcToBorrow);
    }

    function createLedgerEntryAndPositionToken(
        OpenPositionParams calldata params,
        uint256 sharesReceived
    )
        internal
        returns (uint256)
    {
        LedgerEntry memory newEntry;

        newEntry.collateralAmount = params.collateralAmount;
        newEntry.strategyAddress = params.strategy;
        newEntry.strategyShares = sharesReceived;
        newEntry.wbtcDebtAmount = params.wbtcToBorrow;
        newEntry.positionOpenBlock = block.number;
        newEntry.positionExpirationBlock =
            newEntry.positionOpenBlock + leveragedStrategy.getPositionLifetimeInBlocks(params.strategy);
        newEntry.liquidationBuffer = leveragedStrategy.getLiquidationBuffer(params.strategy);
        uint256 nftId = positionToken.mint(msg.sender);

        positionLedger.createNewPositionEntry(nftId, newEntry);

        return nftId;
    }

    function previewOpenPosition(OpenPositionParams calldata params) external view returns (uint256) {
        if (leveragedStrategy.getQuota(params.strategy) < params.wbtcToBorrow) {
            revert ErrorsLeverageEngine.ExceedBorrowQuota();
        }

        if (
            leveragedStrategy.isCollateralToBorrowRatioAllowed(
                params.strategy, params.collateralAmount, params.wbtcToBorrow
            ) == false
        ) {
            revert ErrorsLeverageEngine.ExceedBorrowLimit();
        }

        return leveragedStrategy.getEstimateSharesForWBTCDeposit(
            params.strategy, params.collateralAmount + params.wbtcToBorrow
        );
    }
}
