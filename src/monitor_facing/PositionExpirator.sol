// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import "src/monitor_facing/base/ClosePositionBase.sol"; // Import the PositionManagementBase contract
import "src/libs/PositionCallParams.sol";

import "src/libs/ErrorsLeverageEngine.sol";
import "src/libs/EventsLeverageEngine.sol";
import "src/interfaces/IExpiredVault.sol";
import "src/internal/LeveragedStrategy.sol";
import "src/internal/ProtocolParameters.sol";
import "src/internal/PositionLedger.sol";

contract PositionExpirator is ClosePositiontBase {
    function expirePosition(
        uint256 nftID,
        ClosePositionParams calldata params
    )
        external
        onlyRole(ProtocolRoles.MONITOR_ROLE)
    {
        // Check position state -> revert with PositionNotEligibleForExpiration
        PositionState state = positionLedger.getPositionState(nftID);
        if (state != PositionState.LIVE) revert ErrorsLeverageEngine.PositionNotLive();

        // Check if eligible for expiration -> revert with PositionNotEligibleForExpiration
        bool isPositionEligibleForExpiration = positionLedger.isPositionEligibleForExpiration(nftID);
        if (!isPositionEligibleForExpiration) revert ErrorsLeverageEngine.NotEligibleForExpiration();

        uint256 strategyTokenAmountRecieved = unwindPosition(nftID);

        uint256 wbtcReceived = swapStrategyTokenToWbtc(strategyTokenAmountRecieved, params);

        // Send WBTC back to vault
        repayLiquidatedPositionDebt(nftID, wbtcReceived);

        // Change state of position to expired
        positionLedger.setPositionState(nftID, PositionState.EXPIRED);
    }

    function previewExpirePosition(
        uint256[] memory nftIDs,
        address strategy
    )
        external
        view
        returns (uint256 estimatedWBTC)
    {
        uint256 totalShares = 0;

        // Iterate over all NFT IDs to aggregate the total shares
        for (uint256 i = 0; i < nftIDs.length; i++) {
            LedgerEntry memory position = positionLedger.getPosition(nftIDs[i]);

            // Verify each position
            require(position.state == PositionState.LIVE, "Position not LIVE or already processed");
            require(block.number >= position.positionExpirationBlock, "Position not expired");
            require(position.strategyAddress == strategy, "Position does not belong to the strategy");

            totalShares = totalShares += position.strategyShares;
        }

        // Here, we assume the strategy has a function to give us an estimate of the WBTC for the shares
        estimatedWBTC = strategy.previewRedeem(totalShares);
    }
}
