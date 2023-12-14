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


/// @title LeverageEngine Contract
/// @notice This contract facilitates the management of strategy configurations and admin parameters for the Leverage
/// Engine.
/// @notice Leverage Engine is upgradable

contract PositionCloser is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    struct ClosePositionParams {
        uint256 nftId;
        uint256 minWBTC;
        SwapManager.SwapRoute swapRoute;
        bytes swapData;
        address exchange;
    }

    uint256 internal constant BASE_DENOMINATOR = 10_000;
    uint8 internal constant WBTC_DECIMALS = 8;
    IERC20 internal constant wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    address public monitor;

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

        setExpiredVault(dependencies.expiredVault);

        wbtc.approve(dependencies.wbtcVault, type(uint256).max);
    }  

    function setMonitor(address _monitor) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        if (monitor != address(0)) {
            _revokeRole(ProtocolRoles.MONITOR_ROLE, monitor);
        }
        monitor = _monitor;
        _grantRole(ProtocolRoles.MONITOR_ROLE, _monitor);
        emit EventsLeverageEngine.MonitorUpdated(_monitor);
    }

    function setExpiredVault(address _expiredVault) public onlyRole(ProtocolRoles.ADMIN_ROLE) {
        if (expiredVault != address(0)) {
            wbtc.approve(expiredVault, 0);
            _revokeRole(ProtocolRoles.EXPIRED_VAULT_ROLE, expiredVault);
        }

        expiredVault = _expiredVault;
        _grantRole(ProtocolRoles.EXPIRED_VAULT_ROLE, _expiredVault);
        wbtc.approve(_expiredVault, type(uint256).max);

        emit EventsLeverageEngine.ExpiredVaultUpdated(_expiredVault);
    }

    ///////////// User functions /////////////

   /*
   function closePosition(
        uint256 nftId,
        uint256 minWBTC,
        SwapManager.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
   */

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


    ///////////// Monitor functions /////////////

    /// @notice Allows the monitor to liquidate a position.
    /// 1. Close position
    ///     * 1.2. Find how many shares belong to this nftID
    ///     * 1.3. call strategy redeem with the amount of shares
    ///     * 1.4. now we get the underlying token (e.g.: ETH) back
    /// * 2. Swap underlying token to WBTC
    /// * 3. Check that the amount of WBTC we have is < debt * liquidationBuffer - if not, revert V
    /// * 4. pay back debt V
    /// * 5. if something left
    ///     * 5.1. take liquidation fee
    ///     * 5.2. send whatever left to expiration vault
    ///
    /// @param nftId The ID of the NFT representing the position.
    /// @param minWBTC Minimum amount of WBTC expected after position closure.
    /// @param swapRoute Route to be used for swapping
    /// @param swapData Swap data for the swap adapter
    /// @param exchange Exchange to be used for swapping
    function liquidatePosition(
        uint256 nftId,
        uint256 minWBTC,
        SwapManager.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        external
        onlyRole(ProtocolRoles.MONITOR_ROLE)
    {
        LedgerEntry memory position = positionLedger.getPosition(nftId);

        if (position.state != PositionState.LIVE) revert ErrorsLeverageEngine.PositionNotLive();

        uint256 wbtcReceived = _unwindPosition(position, swapRoute, swapData, exchange);

        // Repay WBTC debt
        if (wbtcReceived > position.wbtcDebtAmount * position.liquidationBuffer / (10 ** WBTC_DECIMALS)) {
            revert ErrorsLeverageEngine.NotEligibleForLiquidation();
        }

        if (wbtcReceived < minWBTC) revert ErrorsLeverageEngine.NotEnoughTokensReceived();

        // Return WBTC debt to WBTC vault
        wbtcVault.repayDebt(nftId, position.wbtcDebtAmount);

        if (wbtcReceived > position.wbtcDebtAmount) {
            uint256 wbtcLeft = wbtcReceived - position.wbtcDebtAmount;
            uint256 liquidationFeeAmount =
                leveragedStrategy.getLiquidationFee(position.strategyAddress) * wbtcLeft / (10 ** WBTC_DECIMALS);
            uint256 claimableAmount = wbtcLeft - liquidationFeeAmount;

            address feeCollector = protocolParameters.getFeeCollector();

            wbtc.transfer(feeCollector, liquidationFeeAmount);

            IExpiredVault(expiredVault).deposit(claimableAmount);
            positionLedger.setClaimableAmount(nftId, claimableAmount);
        }

        positionLedger.setPositionState(nftId, PositionState.LIQUIDATED);

        // TODO fix event
        emit EventsLeverageEngine.PositionLiquidated(nftId, address(0), position.wbtcDebtAmount, 0, 0);
    

    }

    ///////////// Expired Vault functions /////////////

    /// @notice ExpiredVault will call this function to close an expired position.
    /// @param nftID The ID of the NFT representing the position.
    function closeExpiredOrLiquidatedPosition(
        uint256 nftID,
        address sender
    )
        external
        onlyRole(ProtocolRoles.MONITOR_ROLE)
    {
        // Check if the user owns the NFT
        if (positionToken.ownerOf(nftID) != sender) revert ErrorsLeverageEngine.NotOwner();

        LedgerEntry memory position = positionLedger.getPosition(nftID);

        // Check if the NFT state is Expired or Liquidated
        if (
            position.state != PositionState.EXPIRED
                && position.state != PositionState.LIQUIDATED
        ) revert ErrorsLeverageEngine.PositionNotExpiredOrLiquidated();

        // Rememver the received amount for emitting the event
        uint256 receivedAmount = position.claimableAmount;

        // Update the ledger
        positionLedger.setPositionState(nftID, PositionState.CLOSED);
    
        // Burn the NFT
        positionToken.burn(nftID);

        // Emit event
        // No exit fee is charged for expired positions
        emit EventsLeverageEngine.PositionClosed(
            nftID, sender, receivedAmount, position.wbtcDebtAmount);
    }

    ///////////// View functions /////////////

    
    function getCurrentExpiredVault() public view returns (address) {
        return expiredVault;
    }

    ///////////// Internal functions /////////////

   

    /**
     * @notice Get the token prices from oracles and check if the received token amount is enough
     * @param targetToken Token of the strategy
     * @param wbtcAmount Total WBTC amount to swap and deposit into strategy
     * @return expectedTargetTokenAmount Expected amount of target token
     */
    function _checkOracles(
        address targetToken,
        uint256 wbtcAmount
    )
        internal
        view
        returns (uint256 expectedTargetTokenAmount)
    {
        uint8 targetTokenDecimals = IERC20Detailed(targetToken).decimals();
        uint8 targetTokenOracleDecimals = oracleManager.getUSDOracleDecimals(targetToken);
        uint256 wbtcPrice = oracleManager.getLatestTokenPriceInUSD(address(wbtc)); // in USD
        uint256 targetTokenPrice = oracleManager.getLatestTokenPriceInUSD(targetToken); // in USD

        expectedTargetTokenAmount = (
            (
                (wbtcAmount * wbtcPrice / 10 ** WBTC_DECIMALS)
                    * (10 ** (targetTokenDecimals + targetTokenOracleDecimals)) / 10 ** WBTC_DECIMALS
            ) / targetTokenPrice
        );
    }

     function _unwindPosition(
        LedgerEntry memory position,
        SwapManager.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        internal
        returns (uint256 wbtcReceived)
    {
        // Unwind the position
        uint256 assetsReceived = leverageDepositor.redeem(position.strategyAddress, position.strategyShares);
        address strategyAsset = IMultiPoolStrategy(position.strategyAddress).asset();
        
        // Swap the assets to WBTC
        ISwapAdapter swapAdapter = swapManager.getSwapAdapterForRoute(swapRoute);
        
        ISwapAdapter.SwapWbtcParams memory swapParams = ISwapAdapter.SwapWbtcParams({
            otherToken: IERC20(strategyAsset),
            fromAmount: assetsReceived,
            payload: swapData,
            recipient: address(this)
        });

        IERC20(strategyAsset).transfer(address(swapAdapter), assetsReceived);
        wbtcReceived = swapAdapter.swapToWbtc(swapParams);
            
    }
}
