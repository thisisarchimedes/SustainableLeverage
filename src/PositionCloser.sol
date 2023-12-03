// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/ILeverageEngine.sol";
import "./interfaces/IERC20Detailed.sol";
import { IWBTCVault } from "./interfaces/IWBTCVault.sol";
import { IExpiredVault } from "./interfaces/IExpiredVault.sol";
import { ILeverageDepositor } from "./interfaces/ILeverageDepositor.sol";
import { IOracle } from "./interfaces/IOracle.sol";
import { PositionToken } from "./PositionToken.sol";
import { SwapAdapter } from "./SwapAdapter.sol";
import { IMultiPoolStrategy } from "./interfaces/IMultiPoolStrategy.sol";
import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";
import { ProtocolRoles } from "./libs/ProtocolRoles.sol";
import { DependencyAddresses } from "./libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "./libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "./libs/EventsLeverageEngine.sol";
import { LeveragedStrategy } from "./LeveragedStrategy.sol";
import { ProtocolParameters } from "./ProtocolParameters.sol";
import { OracleManager } from "src/OracleManager.sol";
import { PositionLedger, LedgerEntry, PositionState } from "src/PositionLedger.sol";


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

    address public monitor;

    IWBTCVault internal wbtcVault;
    PositionToken internal positionToken;
    ILeverageDepositor internal leverageDepositor;
    SwapAdapter internal swapAdapter;
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
        swapAdapter = SwapAdapter(dependencies.swapAdapter);
        wbtcVault = IWBTCVault(dependencies.wbtcVault);
        leveragedStrategy = LeveragedStrategy(dependencies.leveragedStrategy);
        protocolParameters = ProtocolParameters(dependencies.protocolParameters);
        oracleManager = OracleManager(dependencies.oracleManager);
        positionLedger = PositionLedger(dependencies.positionLedger);

        setExpiredVault(dependencies.expiredVault);

        wbtc.approve(dependencies.wbtcVault, type(uint256).max);
    }  

    // TODO: remove this one - we have setDependecies
    function changeSwapAdapter(address _swapAdapter) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        swapAdapter = SwapAdapter(_swapAdapter);
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

   
    /// @notice Allows a user to close their leverage position.
    /// @param nftId The ID of the NFT representing the position.
    /// @param minWBTC Minimum amount of WBTC expected after position closure.
    /// @param swapRoute Route to be used for swapping
    /// @param swapData Swap data for the swap adapter
    /// @param exchange Exchange to be used for swapping
    function closePosition(
        uint256 nftId,
        uint256 minWBTC,
        SwapAdapter.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        external
    {

        if (positionToken.ownerOf(nftId) != msg.sender) {
            revert ErrorsLeverageEngine.NotOwner();
        }

        if (positionLedger.getPositionState(nftId) != PositionState.LIVE) {
            revert ErrorsLeverageEngine.PositionNotLive();
        }

        LedgerEntry memory position = positionLedger.getPosition(nftId);


        uint256 wbtcDebtAmount = positionLedger.getDebtAmount(nftId);
        
        uint256 wbtcReceived = _unwindPosition(position, swapRoute, swapData, exchange);

        if (wbtcReceived < wbtcDebtAmount) {
            revert ErrorsLeverageEngine.NotEnoughWBTC();
        }
        wbtcVault.repay(nftId, wbtcDebtAmount);

        // exit fees
        uint256 exitFee = protocolParameters.getExitFee();
        uint256 exitFeeAmount = (wbtcReceived - wbtcDebtAmount) * exitFee / BASE_DENOMINATOR;        
        wbtc.transfer(protocolParameters.getFeeCollector(), exitFeeAmount);

        // Send the rest of WBTC to the user
        uint256 wbtcLeft = wbtcReceived - wbtcDebtAmount - exitFeeAmount;
        if (wbtcLeft < minWBTC) revert ErrorsLeverageEngine.NotEnoughTokensReceived();
        wbtc.transfer(msg.sender, wbtcLeft);

        positionLedger.setPositionState(nftId, PositionState.CLOSED);
        
        positionToken.burn(nftId);

        // emit event
        emit EventsLeverageEngine.PositionClosed(
            nftId, msg.sender, position.strategyAddress, wbtcLeft, wbtcDebtAmount, exitFeeAmount
        );
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
        SwapAdapter.SwapRoute swapRoute,
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
        wbtcVault.repay(nftId, position.wbtcDebtAmount);

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
            nftID, sender, position.strategyAddress, receivedAmount, position.wbtcDebtAmount, 0
        );
    }

    ///////////// View functions /////////////

    
    function getCurrentExpiredVault() public view returns (address) {
        return expiredVault;
    }

    ///////////// Internal functions /////////////

    function _unwindPosition(
        LedgerEntry memory position,
        SwapAdapter.SwapRoute swapRoute,
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
        IERC20(strategyAsset).transfer(address(swapAdapter), assetsReceived);
        wbtcReceived =
            swapAdapter.swap(IERC20(strategyAsset), wbtc, assetsReceived, exchange, swapData, swapRoute, address(this));
    }



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
        uint8 targetTokenOracleDecimals = oracleManager.getOracleDecimals(targetToken);
        uint256 wbtcPrice = oracleManager.getLatestPrice(address(wbtc)); // in USD
        uint256 targetTokenPrice = oracleManager.getLatestPrice(targetToken); // in USD

        expectedTargetTokenAmount = (
            (
                (wbtcAmount * wbtcPrice / 10 ** WBTC_DECIMALS)
                    * (10 ** (targetTokenDecimals + targetTokenOracleDecimals)) / 10 ** WBTC_DECIMALS
            ) / targetTokenPrice
        );
    }
}
