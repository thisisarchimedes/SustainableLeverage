// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

library ProtocolRoles {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");
    bytes32 public constant EXPIRED_VAULT_ROLE = keccak256("EXPIRED_VAULT_ROLE");
    bytes32 public constant INTERNAL_CONTRACT_ROLE = keccak256("INTERNAL_CONTRACT_ROLE");
}
