// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ClosePositionInternal } from "src/libs/ClosePositionInternal.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { PositionLedger } from "src/internal/PositionLedger.sol";

contract ClosePositiontBase is ClosePositionInternal, AccessControlUpgradeable {
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

        WBTC.approve(dependencies.expiredVault, type(uint256).max);
        WBTC.approve(dependencies.wbtcVault, type(uint256).max);
    }

    function setMonitor(address _monitor) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        if (monitor != address(0)) {
            _revokeRole(ProtocolRoles.MONITOR_ROLE, monitor);
        }
        monitor = _monitor;
        _grantRole(ProtocolRoles.MONITOR_ROLE, _monitor);
    }

    function setExpiredVault(address _expiredVault) public onlyRole(ProtocolRoles.ADMIN_ROLE) {
        if (expiredVault != address(0)) {
            WBTC.approve(expiredVault, 0);
            _revokeRole(ProtocolRoles.EXPIRED_VAULT_ROLE, expiredVault);
        }

        expiredVault = _expiredVault;
        _grantRole(ProtocolRoles.EXPIRED_VAULT_ROLE, _expiredVault);
        WBTC.approve(_expiredVault, type(uint256).max);
    }

    function getCurrentExpiredVault() public view returns (address) {
        return expiredVault;
    }

    function repayLiquidatedPositionDebt(uint256 nftId, uint256 wbtcReceived) internal returns (uint256 leftoverWbtc) {
        uint256 wbtcDebtAmount = positionLedger.getDebtAmount(nftId);

        if (wbtcReceived <= wbtcDebtAmount) {
            WBTC_VAULT.repayDebt(nftId, wbtcReceived);
            return 0;
        }

        WBTC_VAULT.repayDebt(nftId, wbtcDebtAmount);
        return wbtcReceived - wbtcDebtAmount;
    }
}
