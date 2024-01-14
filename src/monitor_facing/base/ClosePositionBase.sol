// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "src/libs/ClosePositionInternal.sol";
import "src/libs/ProtocolRoles.sol";
import "src/libs/DependencyAddresses.sol";
import "src/internal/PositionLedger.sol";

contract PositionManagementBase is ClosePositionInternal, AccessControlUpgradeable {
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
    }

    function setExpiredVault(address _expiredVault) public onlyRole(ProtocolRoles.ADMIN_ROLE) {
        if (expiredVault != address(0)) {
            wbtc.approve(expiredVault, 0);
            _revokeRole(ProtocolRoles.EXPIRED_VAULT_ROLE, expiredVault);
        }

        expiredVault = _expiredVault;
        _grantRole(ProtocolRoles.EXPIRED_VAULT_ROLE, _expiredVault);
        wbtc.approve(_expiredVault, type(uint256).max);
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
}
