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

contract PositionExpirator is
    PositionManagementBase // Extend from PositionManagementBase
{
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
}
