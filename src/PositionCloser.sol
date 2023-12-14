// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "src/interfaces/IERC20Detailed.sol";
import { IWBTCVault } from "src/interfaces/IWBTCVault.sol";
import { IExpiredVault } from "src/interfaces/IExpiredVault.sol";
import { ILeverageDepositor } from "src/interfaces/ILeverageDepositor.sol";
import { IOracle } from "src/interfaces/IOracle.sol";
import { PositionToken } from "src/PositionToken.sol";
import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";
import { IMultiPoolStrategy } from "src/interfaces/IMultiPoolStrategy.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";
import { LeveragedStrategy } from "src/LeveragedStrategy.sol";
import { ProtocolParameters } from "src/ProtocolParameters.sol";
import { OracleManager } from "src/OracleManager.sol";
import { PositionLedger, LedgerEntry, PositionState } from "src/PositionLedger.sol";
import { SwapManager } from "src/SwapManager.sol";
import { ClosePositionParams } from "src/libs/PositionCallParams.sol";


/// @title LeverageEngine Contract
/// @notice This contract facilitates the management of strategy configurations and admin parameters for the Leverage
/// Engine.
/// @notice Leverage Engine is upgradable

contract PositionCloser is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

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

    address internal expiredVault;

    constructor() {
        _disableInitializers();
    }

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

        wbtc.approve(dependencies.wbtcVault, type(uint256).max);
    }  

    function closePosition(ClosePositionParams calldata params) external {      

        revertIfUserNotAllowedToClosePosition(params.nftId);
    
        uint256 strategyTokenAmountRecieved = unwindPosition(params.nftId);
        uint256 wbtcReceived = swapStrategyTokenToWbtc(strategyTokenAmountRecieved, params);

        uint256 wbtcDebtAmount = positionLedger.getDebtAmount(params.nftId); 
        if (wbtcReceived < wbtcDebtAmount) {
            revert ErrorsLeverageEngine.NotEnoughWBTC();
        }

        wbtcVault.repayDebt(params.nftId, wbtcDebtAmount);

        uint256 exitFeeAmount = collectExitFeesAfterDebt(wbtcReceived - wbtcDebtAmount);
        
        uint256 finalUserBalance = wbtcReceived - wbtcDebtAmount - exitFeeAmount;
        sendBalanceToUser(finalUserBalance, params.minWBTC);
                
        recordPositionClosed(params.nftId, finalUserBalance);
    }


    function revertIfUserNotAllowedToClosePosition(uint256 nftId) internal view {

        if (positionToken.ownerOf(nftId) != msg.sender) {
            revert ErrorsLeverageEngine.NotOwner();
        }

        if (positionLedger.getPositionState(nftId) != PositionState.LIVE) {
            revert ErrorsLeverageEngine.PositionNotLive();
        }

        if (isMinPositionDurationPassed(nftId) == false) {
            revert ErrorsLeverageEngine.PositionMustLiveForMinDuration();
        }
    }

    function isMinPositionDurationPassed(uint256 nftId) internal view returns (bool) {
        return block.number >= positionLedger.getOpenBlock(nftId) + protocolParameters.getMinPositionDurationInBlocks();
    }

     function unwindPosition(uint256 nftId) internal returns (uint256) {

        address strategyAddress = positionLedger.getStrategyAddress(nftId);
        uint256 strategyShares = positionLedger.getStrategyShares(nftId);

        return leverageDepositor.redeem(strategyAddress, strategyShares);
    }

    function swapStrategyTokenToWbtc(uint256 strategyTokenAmount, ClosePositionParams calldata params) internal returns (uint256) {

        address strategyAddress = positionLedger.getStrategyAddress(params.nftId);
        address strategyUnderlyingToken = leveragedStrategy.getStrategyValueAsset(strategyAddress); 
        ISwapAdapter swapAdapter = swapManager.getSwapAdapterForRoute(params.swapRoute);

        ISwapAdapter.SwapWbtcParams memory swapParams = ISwapAdapter.SwapWbtcParams({
            otherToken: IERC20(strategyUnderlyingToken),
            fromAmount: strategyTokenAmount,
            payload: params.swapData,
            recipient: address(this)
        });
      
        IERC20(strategyUnderlyingToken).transfer(address(swapAdapter), strategyTokenAmount); 
        return swapAdapter.swapToWbtc(swapParams);
    }

    function collectExitFeesAfterDebt(uint256 wbtcAmountAfterDebt) internal returns(uint256) {
        
        uint256 exitFee = protocolParameters.getExitFee();
        uint256 exitFeeAmount = wbtcAmountAfterDebt * exitFee / BASE_DENOMINATOR;        
        wbtc.transfer(protocolParameters.getFeeCollector(), exitFeeAmount);

        return exitFeeAmount;
    }

    function sendBalanceToUser(uint256 wbtcLeft, uint256 minWbtc) internal {
        
        if (wbtcLeft < minWbtc) {
            revert ErrorsLeverageEngine.NotEnoughTokensReceived();
        }
        wbtc.transfer(msg.sender, wbtcLeft);
    }

    function recordPositionClosed(uint256 nftId, uint256 finalUserBalance) internal {

        emit EventsLeverageEngine.PositionClosed(
            nftId, 
            msg.sender, 
            finalUserBalance, 
            positionLedger.getDebtAmount(nftId)
        );

        positionLedger.setPositionState(nftId, PositionState.CLOSED);
        positionToken.burn(nftId);
    }
}
