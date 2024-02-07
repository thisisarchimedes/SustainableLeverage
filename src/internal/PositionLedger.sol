// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";

enum PositionState {
    UNINITIALIZED,
    LIVE,
    EXPIRED,
    LIQUIDATED,
    CLOSED
}

struct LedgerEntry {
    uint256 collateralAmount;
    address strategyAddress;
    uint256 strategyShares;
    uint256 wbtcDebtAmount;
    uint256 poistionOpenBlock;
    uint256 positionExpirationBlock;
    uint256 liquidationBuffer;
    PositionState state;
    uint256 claimableAmount;
}

/// @title LedgerManager Contract
/// @notice Manages the position ledger for the Leverage Engine system.
contract PositionLedger is AccessControlUpgradeable {
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    mapping(uint256 => LedgerEntry) public entries; // Mapping from NFT ID to LedgerEntry

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionOpener);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionCloser);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionLiquidator);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionExpirator);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.expiredVault);
    }

    function createNewPositionEntry(
        uint256 nftID,
        LedgerEntry memory entry
    )
        external
        onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE)
    {
        entries[nftID] = entry;
    }

    // TODO: remove this one
    function getPosition(uint256 nftID) external view returns (LedgerEntry memory) {
        return entries[nftID];
    }

    function setPositionState(
        uint256 nftID,
        PositionState state
    )
        external
        onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE)
    {
        entries[nftID].state = state;

        if (state == PositionState.CLOSED) {
            entries[nftID].claimableAmount = 0;
        }
    }

    function getCollateralAmount(uint256 nftID) external view returns (uint256) {
        return entries[nftID].collateralAmount;
    }

    function getPositionState(uint256 nftID) external view returns (PositionState) {
        return entries[nftID].state;
    }

    function getStrategyAddress(uint256 nftID) external view returns (address) {
        return entries[nftID].strategyAddress;
    }

    function getDebtAmount(uint256 nftID) external view returns (uint256) {
        return entries[nftID].wbtcDebtAmount;
    }

    function getStrategyShares(uint256 nftID) external view returns (uint256) {
        return entries[nftID].strategyShares;
    }

    function getClaimableAmount(uint256 nftID) external view returns (uint256) {
        return entries[nftID].claimableAmount;
    }

    function getOpenBlock(uint256 nftID) external view returns (uint256) {
        return entries[nftID].poistionOpenBlock;
    }

    function getExpirationBlock(uint256 nftID) public view returns (uint256) {
        return entries[nftID].positionExpirationBlock;
    }

    function isPositionEligibleForExpiration(uint256 nftID) external view returns (bool) {
        return getExpirationBlock(nftID) < block.number;
    }

    function setClaimableAmount(
        uint256 nftID,
        uint256 claimableAmount
    )
        external
        onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE)
    {
        entries[nftID].claimableAmount = claimableAmount;
    }

    // TODO: remove this one
    function claimableAmountWasClaimed(uint256 nftID) external onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE) {
        PositionState state = entries[nftID].state;
        if (state != PositionState.EXPIRED && state != PositionState.LIQUIDATED) {
            revert ErrorsLeverageEngine.PositionNotExpiredOrLiquidated();
        }

        entries[nftID].claimableAmount = 0;
    }
}
