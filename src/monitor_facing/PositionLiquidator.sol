// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { ClosePositiontBase } from "src/monitor_facing/base/ClosePositionBase.sol";
import { ClosePositionParams } from "src/libs/PositionCallParams.sol";

import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";
import { IExpiredVault } from "src/interfaces/IExpiredVault.sol";
import { ProtocolRoles, PositionState } from "src/internal/PositionLedger.sol";

contract PositionLiquidator is ClosePositiontBase {
    function liquidatePosition(ClosePositionParams calldata params) external onlyRole(ProtocolRoles.MONITOR_ROLE) {
        uint256 nftId = params.nftId;
        uint256 strategyTokenAmountRecieved = unwindPosition(nftId);
        uint256 wbtcReceived = swapStrategyTokenToWbtc(strategyTokenAmountRecieved, params);

        revertIfNotAllowedToLiquidate(params, wbtcReceived);

        uint256 leftoverWbtc = repayPositionDebt(nftId, wbtcReceived);

        uint256 feePaid = collectLiquidationFee(params, leftoverWbtc);

        uint256 userClaimableAmount = leftoverWbtc - feePaid;
        setNftIdVaultBalance(nftId, userClaimableAmount);

        positionLedger.setPositionState(nftId, PositionState.LIQUIDATED);

        uint256 wbtcDebtPaid = wbtcReceived - leftoverWbtc;
        emit EventsLeverageEngine.PositionLiquidated(
            nftId, positionLedger.getStrategyAddress(nftId), wbtcDebtPaid, userClaimableAmount, feePaid
        );
    }

    function revertIfNotAllowedToLiquidate(ClosePositionParams calldata params, uint256 wbtcReceived) internal view {
        if (positionLedger.getPositionState(params.nftId) != PositionState.LIVE) {
            revert ErrorsLeverageEngine.PositionNotLive();
        }

        if (wbtcReceived < params.minWBTC) {
            revert ErrorsLeverageEngine.NotEnoughTokensReceived();
        }

        address strategyAddress = positionLedger.getStrategyAddress(params.nftId);
        uint256 wbtcDebtAmount = positionLedger.getDebtAmount(params.nftId);
        if (leveragedStrategy.isPositionLiquidatable(strategyAddress, wbtcReceived, wbtcDebtAmount) == false) {
            revert ErrorsLeverageEngine.NotEligibleForLiquidation();
        }
    }

    function collectLiquidationFee(
        ClosePositionParams calldata params,
        uint256 leftoverWbtc
    )
        internal
        returns (uint256 feePaid)
    {
        if (leftoverWbtc == 0) {
            return 0;
        }

        address strategyAddress = positionLedger.getStrategyAddress(params.nftId);
        feePaid = leveragedStrategy.getLiquidationFee(strategyAddress) * leftoverWbtc / (10 ** WBTC_DECIMALS);

        address feeCollector = protocolParameters.getFeeCollector();
        WBTC.transfer(feeCollector, feePaid);
    }

    function setNftIdVaultBalance(uint256 nftId, uint256 balance) internal {
        positionLedger.setClaimableAmount(nftId, balance);

        if (balance == 0) {
            return;
        }

        IExpiredVault(expiredVault).deposit(balance);
    }
}
