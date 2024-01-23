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
        uint256 nftId,
        ClosePositionParams calldata params
    )
        external
        onlyRole(ProtocolRoles.MONITOR_ROLE)
    {
        // Check position state -> revert with PositionNotEligibleForExpiration
        PositionState state = positionLedger.getPositionState(nftId);
        if (state != PositionState.LIVE) revert ErrorsLeverageEngine.PositionNotLive();

        // Check if eligible for expiration -> revert with PositionNotEligibleForExpiration
        bool isPositionEligibleForExpiration = positionLedger.isPositionEligibleForExpiration(nftId);
        if (!isPositionEligibleForExpiration) revert ErrorsLeverageEngine.NotEligibleForExpiration();

        uint256 strategyTokenAmountRecieved = unwindPosition(nftId);

        uint256 wbtcReceived = swapStrategyTokenToWbtc(strategyTokenAmountRecieved, params);

        // Send WBTC back to vault
        repayLiquidatedPositionDebt(nftId, wbtcReceived);
        uint256 wbtcDebtAmount = positionLedger.getDebtAmount(params.nftId);

        uint256 finalUserBalance = wbtcReceived - wbtcDebtAmount;

        // Change state of position to expired
        positionLedger.setPositionState(nftId, PositionState.EXPIRED);

        //emit event
        emit EventsLeverageEngine.PositionExpired(
            nftId, positionLedger.getStrategyAddress(nftId), finalUserBalance, wbtcDebtAmount
        );
    }
}
