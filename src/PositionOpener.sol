// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IERC20Detailed.sol";
import { IWBTCVault } from "./interfaces/IWBTCVault.sol";
import { IExpiredVault } from "./interfaces/IExpiredVault.sol";
import { ILeverageDepositor } from "./interfaces/ILeverageDepositor.sol";
import { IOracle } from "./interfaces/IOracle.sol";
import { PositionToken } from "./PositionToken.sol";
import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";
import { SwapManager } from "./SwapManager.sol";
import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";
import { ProtocolRoles } from "./libs/ProtocolRoles.sol";
import { DependencyAddresses } from "./libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "./libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "./libs/EventsLeverageEngine.sol";
import { LeveragedStrategy } from "./LeveragedStrategy.sol";
import { ProtocolParameters } from "./ProtocolParameters.sol";
import { OracleManager } from "./OracleManager.sol";
import { PositionLedger, LedgerEntry, PositionState } from "./PositionLedger.sol";

/// @title PositionManager Contract
/// @notice Supports only WBTC tokens for now
contract PositionOpener is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    struct OpenPositionParams {
        uint256 collateralAmount;
        uint256 wbtcToBorrow;
        address strategy;
        uint256 minStrategyShares;
        SwapManager.SwapRoute swapRoute;
        bytes swapData;
    }

    uint256 internal constant BASE_DENOMINATOR = 10_000;
    uint8 internal constant WBTC_DECIMALS = 8;
    IERC20 internal constant wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    IWBTCVault internal wbtcVault;
    PositionToken internal positionToken;
    ILeverageDepositor internal leverageDepositor;
    SwapManager internal swapManager;
    LeveragedStrategy internal leveragedStrategy;
    ProtocolParameters internal protocolParameters;
    OracleManager internal oracleManager;
    PositionLedger internal positionLedger;

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
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

    // TODO: remove this one 
    function openPosition(
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        address strategy,
        uint256 minStrategyShares,
        SwapManager.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        external
        returns (uint256 nftId)
    {

        OpenPositionParams memory params = PositionOpener.OpenPositionParams({
                collateralAmount: collateralAmount,
                wbtcToBorrow: wbtcToBorrow,
                minStrategyShares: minStrategyShares,
                strategy: strategy,
                swapRoute: swapRoute,
                swapData: swapData
            });

        nftId = this.openPosition(params);

        return nftId;
         
    }
    function openPosition(OpenPositionParams calldata params) public returns (uint256) {

        if (leveragedStrategy.isCollateralToBorrowRatioAllowed(params.strategy, params.collateralAmount, params.wbtcToBorrow) == false) {
            revert ErrorsLeverageEngine.ExceedBorrowLimit();
        }

        leveragedStrategy.reduceQuotaBy(params.strategy, params.wbtcToBorrow);

        ISwapAdapter swapAdapter = swapManager.getSwapAdapterForRoute(params.swapRoute);

        sendWbtcToSwapAdapter(address(swapAdapter), params);

        uint256 receivedTokenAmount = swapWbtcToStrategyToken(swapAdapter, params);
        
        if (isSwapReturnedEnoughTokens(params, receivedTokenAmount) == false) {
            revert ErrorsLeverageEngine.NotEnoughTokensReceived();
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
            block.number + leveragedStrategy.getPositionLifetime(params.strategy),
            sharesReceived
        );

        return nftId;
    }

    function sendWbtcToSwapAdapter(address swapAdapter, OpenPositionParams calldata params) internal {

        wbtcVault.borrowAmountTo(params.wbtcToBorrow, swapAdapter);         
        wbtc.safeTransferFrom(msg.sender, swapAdapter, params.collateralAmount);

    }

    function swapWbtcToStrategyToken(ISwapAdapter swapAdapter, OpenPositionParams calldata params) internal returns (uint256) {

        address strategyUnderlyingToken = leveragedStrategy.getStrategyValueAsset(params.strategy);
        ISwapAdapter.SwapWbtcParams memory swapParams = ISwapAdapter.SwapWbtcParams({
            otherToken: IERC20(strategyUnderlyingToken),
            fromAmount: params.collateralAmount + params.wbtcToBorrow,
            payload: params.swapData,
            recipient: address(leverageDepositor)
        });
      
        return swapAdapter.swapFromWbtc(swapParams);
    }

    function isSwapReturnedEnoughTokens(OpenPositionParams calldata params, uint256 receivedTokenAmount) internal view returns (bool) {
        
        address strategyUnderlyingToken = leveragedStrategy.getStrategyValueAsset(params.strategy);
        uint256 receivedTokensInWbtc = leveragedStrategy.getWBTCValueFromTokenAmount(strategyUnderlyingToken, receivedTokenAmount);
        
        return !leveragedStrategy.isPositionLiquidatable(params.strategy, receivedTokensInWbtc, params.wbtcToBorrow);
    }

    function createLedgerEntryAndPositionToken(OpenPositionParams calldata params, uint256 sharesReceived) internal returns (uint256) {
        LedgerEntry memory newEntry;

        newEntry.collateralAmount = params.collateralAmount;
        newEntry.strategyAddress = params.strategy;
        newEntry.strategyShares = sharesReceived;
        newEntry.wbtcDebtAmount = params.wbtcToBorrow;
        newEntry.positionExpirationBlock = block.number + leveragedStrategy.getPositionLifetime(params.strategy);
        newEntry.liquidationBuffer = leveragedStrategy.getLiquidationBuffer(params.strategy);
        newEntry.state = PositionState.LIVE;
        uint256 nftId = positionToken.mint(msg.sender);
        
        positionLedger.createNewPositionEntry(nftId, newEntry);

        return nftId;
    }

    function previewOpenPosition(OpenPositionParams calldata params) external view returns (uint256) {
 
        if (leveragedStrategy.getQuota(params.strategy) < params.wbtcToBorrow) {
            revert ErrorsLeverageEngine.ExceedBorrowQuota();
        }


        if (leveragedStrategy.isCollateralToBorrowRatioAllowed(params.strategy, params.collateralAmount, params.wbtcToBorrow) == false) {
            revert ErrorsLeverageEngine.ExceedBorrowLimit();
        }

        return leveragedStrategy.getEstimateSharesForWBTCDeposit(params.strategy, params.collateralAmount + params.wbtcToBorrow);
    }
}
