// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

library LocalRoles {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");
    bytes32 public constant EXPIRED_VAULT_ROLE = keccak256("EXPIRED_VAULT_ROLE");
}
