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

contract PositionLiquidator is PositionManagementBase {
    function liquidatePosition(ClosePositionParams calldata params) external onlyRole(ProtocolRoles.MONITOR_ROLE) {
        uint256 nftId = params.nftId;
        uint256 strategyTokenAmountRecieved = unwindPosition(nftId);
        uint256 wbtcReceived = swapStrategyTokenToWbtc(strategyTokenAmountRecieved, params);

        revertIfNotAllowedToLiquidate(params, wbtcReceived);

        uint256 leftoverWbtc = repayLiquidatedPositionDebt(nftId, wbtcReceived);

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
        wbtc.transfer(feeCollector, feePaid);
    }

    function setNftIdVaultBalance(uint256 nftId, uint256 balance) internal {
        positionLedger.setClaimableAmount(nftId, balance);

        if (balance == 0) {
            return;
        }

        IExpiredVault(expiredVault).deposit(balance);
    }
}
