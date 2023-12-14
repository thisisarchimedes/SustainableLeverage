// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "src/interfaces/IERC20Detailed.sol"
;
import { IWBTCVault } from "src/interfaces/IWBTCVault.sol";
import { IExpiredVault } from "src/interfaces/IExpiredVault.sol";
import { ILeverageDepositor } from "src/interfaces/ILeverageDepositor.sol";
import { IOracle } from "src/interfaces/IOracle.sol";
import { PositionToken } from "src/PositionToken.sol";
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
import { ClosePositionParams } from "src/libs/PositionCallParams.sol";
import { ClosePositionInternal } from "src/libs/ClosePositionInternal.sol";
import { SwapManager } from "src/SwapManager.sol";



contract PositionLiquidator is ClosePositionInternal, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    uint8 internal constant WBTC_DECIMALS = 8;
    IERC20 internal constant wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    address public monitor;

    IWBTCVault internal wbtcVault;
    PositionToken internal positionToken;
    ProtocolParameters internal protocolParameters;
    OracleManager internal oracleManager;

    address internal expiredVault;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE)  {

        setDependenciesInternal(dependencies);

        leverageDepositor = ILeverageDepositor(dependencies.leverageDepositor);
        positionToken = PositionToken(dependencies.positionToken);
        swapManager = SwapManager(dependencies.swapManager);
        wbtcVault = IWBTCVault(dependencies.wbtcVault);
        leveragedStrategy = LeveragedStrategy(dependencies.leveragedStrategy);
        protocolParameters = ProtocolParameters(dependencies.protocolParameters);
        oracleManager = OracleManager(dependencies.oracleManager);
        positionLedger = PositionLedger(dependencies.positionLedger);

        setExpiredVault(dependencies.expiredVault);
        wbtc.approve(dependencies.expiredVault, type(uint256).max);

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

    function getCurrentExpiredVault() public view returns (address) {
        return expiredVault;
    }

    function liquidatePosition(ClosePositionParams calldata params) external onlyRole(ProtocolRoles.MONITOR_ROLE) {

        uint256 nftId = params.nftId;
        uint256 strategyTokenAmountRecieved = unwindPosition(nftId);
        uint256 wbtcReceived = swapStrategyTokenToWbtc(strategyTokenAmountRecieved, params);

        revertIfNotAllowedToLiquidate(params, wbtcReceived);

        uint256 leftoverWbtc = repayLiquidatedPositionDebt(nftId, wbtcReceived);
        
        uint256 feePaid = collectLiquidationFee(params, leftoverWbtc);

        setNftIdVaultBalance(nftId, leftoverWbtc - feePaid);

        positionLedger.setPositionState(nftId, PositionState.LIQUIDATED);
    }

    function revertIfNotAllowedToLiquidate(ClosePositionParams calldata params, uint256 wbtcReceived) internal view {
       
        if (positionLedger.getPositionState(params.nftId) != PositionState.LIVE) {
            revert ErrorsLeverageEngine.PositionNotLive();
        }
 
        if (wbtcReceived < params.minWBTC) {
            revert ErrorsLeverageEngine.NotEnoughTokensReceived();
        }

        address strategyAddress = positionLedger.getStrategyAddress(params.nftId);
        uint256 wbtcDebtAmount = positionLedger.getDebtAmount(params.nftId); 
        if (leveragedStrategy.isPositionLiquidatable(strategyAddress, wbtcReceived, wbtcDebtAmount) == false) {
            revert ErrorsLeverageEngine.NotEligibleForLiquidation();
        }
    }

    function repayLiquidatedPositionDebt(uint256 nftId, uint256 wbtcReceived) internal returns(uint256 leftoverWbtc) {

        uint256 wbtcDebtAmount = positionLedger.getDebtAmount(nftId); 

        if (wbtcReceived <= wbtcDebtAmount) {
            wbtcVault.repayDebt(nftId, wbtcReceived);
            return 0;
        }

        wbtcVault.repayDebt(nftId, wbtcDebtAmount);
        return wbtcReceived - wbtcDebtAmount;    
    }

    function collectLiquidationFee(ClosePositionParams calldata params, uint256 leftoverWbtc) internal returns(uint256 feePaid) {
        
        if (leftoverWbtc == 0) {
            return 0;
        }

        address strategyAddress = positionLedger.getStrategyAddress(params.nftId);
        feePaid = leveragedStrategy.getLiquidationFee(strategyAddress) * leftoverWbtc / (10 ** WBTC_DECIMALS);
            
        address feeCollector = protocolParameters.getFeeCollector();
        wbtc.transfer(feeCollector, feePaid);

    }

    function setNftIdVaultBalance(uint256 nftId, uint256 balance) internal {

        positionLedger.setClaimableAmount(nftId, balance);

        if (balance == 0) {
            return;
        }

        IExpiredVault(expiredVault).deposit(balance);
    }
}
