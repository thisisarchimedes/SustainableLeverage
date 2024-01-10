// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "src/interfaces/IERC20Detailed.sol";

import { ClosePositionInternal } from "src/libs/ClosePositionInternal.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ClosePositionParams } from "src/libs/PositionCallParams.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";

import { IExpiredVault } from "src/interfaces/IExpiredVault.sol";
import { IOracle } from "src/interfaces/IOracle.sol";
import { IMultiPoolStrategy } from "src/interfaces/IMultiPoolStrategy.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";

import { LeveragedStrategy } from "src/internal/LeveragedStrategy.sol";
import { ProtocolParameters } from "src/internal/ProtocolParameters.sol";
import { OracleManager } from "src/internal/OracleManager.sol";
import { PositionLedger, LedgerEntry, PositionState } from "src/internal/PositionLedger.sol";

contract PositionExpirator is ClosePositionInternal, AccessControlUpgradeable {
    address internal monitor;
    address internal expiredVault;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        setDependenciesInternal(dependencies);

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

    function repayLiquidatedPositionDebt(uint256 nftId, uint256 wbtcReceived) internal returns (uint256 leftoverWbtc) {
        uint256 wbtcDebtAmount = positionLedger.getDebtAmount(nftId);

        if (wbtcReceived <= wbtcDebtAmount) {
            wbtcVault.repayDebt(nftId, wbtcReceived);
            return 0;
        }

        wbtcVault.repayDebt(nftId, wbtcDebtAmount);
        return wbtcReceived - wbtcDebtAmount;
    }

    function expirePosition(
        uint256 nftID,
        ClosePositionParams calldata params
    )
        external
        onlyRole(ProtocolRoles.MONITOR_ROLE)
    {
        //check position state -> revert with PositionNotEligibleForExpiration
        PositionState state = positionLedger.getPositionState(nftID);
        if (state != PositionState.LIVE) revert ErrorsLeverageEngine.PositionNotLive();

        //check if eligible for expiration -> revert with PositionNotEligibleForExpiration
        bool isPositionEligibleForExpiration = positionLedger.isPositionEligibleForExpiration(nftID);
        if (isPositionEligibleForExpiration == false) revert ErrorsLeverageEngine.NotEligibleForExpiration();

        uint256 strategyTokenAmountRecieved = unwindPosition(nftID);

        uint256 wbtcReceived = swapStrategyTokenToWbtc(strategyTokenAmountRecieved, params);

        //send WBTC back to vault
        repayLiquidatedPositionDebt(nftID, wbtcReceived);

        //change state of position to expired
        positionLedger.setPositionState(nftID, PositionState.EXPIRED);
    }
}
