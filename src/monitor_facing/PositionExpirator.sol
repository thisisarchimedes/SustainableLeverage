// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { ClosePositiontBase } from "src/monitor_facing/base/ClosePositionBase.sol";
import { ClosePositionParams } from "src/libs/PositionCallParams.sol";

import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";

import { ProtocolRoles, PositionState } from "src/internal/PositionLedger.sol";

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

        // Repay debt to WBTC vault
        uint256 leftoverWbtc = repayPositionDebt(nftId, wbtcReceived);

        //send leftover WBTC to expired vault
        setNftIdVaultBalance(nftId, leftoverWbtc);

        // Change state of position to expired
        positionLedger.setPositionState(nftId, PositionState.EXPIRED);

        //emit event
        emit EventsLeverageEngine.PositionExpired(nftId, positionLedger.getStrategyAddress(nftId), leftoverWbtc);
    }
}
