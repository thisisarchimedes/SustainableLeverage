// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

/// @title PositionLedger Library
/// @notice This library manages the ledger entries for leveraged positions.
library PositionLedgerLib {
    enum PositionState {
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
        uint256 positionExpirationBlock;
        uint256 liquidationBuffer;
        PositionState state;
        uint256 claimableAmount;
    }

    // Ledger storage structure to be defined in the calling contract
    struct LedgerStorage {
        mapping(uint256 => LedgerEntry) entries; // Mapping from NFT ID to LedgerEntry
    }

    function getCollateralAmount(LedgerStorage storage self, uint256 nftID) external view returns (uint256) {
        return self.entries[nftID].collateralAmount;
    }

    function getLedgerEntry(LedgerStorage storage self, uint256 nftID) external view returns (LedgerEntry memory) {
        return self.entries[nftID];
    }

    // ... [Similar functions for other ledger entry attributes]

    function setLedgerEntry(LedgerStorage storage self, uint256 nftID, LedgerEntry memory entry) internal {
        self.entries[nftID] = entry;
    }
}
