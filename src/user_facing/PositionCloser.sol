// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { ClosePositionInternal } from "src/libs/ClosePositionInternal.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";
import { ClosePositionParams } from "src/libs/PositionCallParams.sol";

import { PositionState } from "src/internal/PositionLedger.sol";

contract PositionCloser is AccessControlUpgradeable, ClosePositionInternal {
    uint256 internal constant EXIT_FEE_BASE_DENOMINATOR = 10_000;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        setDependenciesInternal(dependencies);

        WBTC.approve(dependencies.wbtcVault, type(uint256).max);
    }

    function closePosition(ClosePositionParams calldata params) external {
        revertIfUserNotAllowedToClosePosition(params.nftId);

        uint256 strategyTokenAmountRecieved = unwindPosition(params.nftId);
        uint256 wbtcReceived = swapStrategyTokenToWbtc(strategyTokenAmountRecieved, params);

        uint256 wbtcDebtAmount = positionLedger.getDebtAmount(params.nftId);
        if (wbtcReceived < wbtcDebtAmount) {
            revert ErrorsLeverageEngine.NotEnoughWBTC();
        }

        wbtcVault.repayDebt(params.nftId, wbtcDebtAmount);

        uint256 exitFeeAmount = collectExitFeesAfterDebt(wbtcReceived - wbtcDebtAmount);

        uint256 finalUserBalance = wbtcReceived - wbtcDebtAmount - exitFeeAmount;
        sendBalanceToUser(finalUserBalance, params.minWBTC);

        recordPositionClosed(params.nftId, finalUserBalance);
    }

    function revertIfUserNotAllowedToClosePosition(uint256 nftId) internal view {
        if (positionToken.ownerOf(nftId) != msg.sender) {
            revert ErrorsLeverageEngine.NotOwner();
        }

        if (positionLedger.getPositionState(nftId) != PositionState.LIVE) {
            revert ErrorsLeverageEngine.PositionNotLive();
        }

        if (isMinPositionDurationPassed(nftId) == false) {
            revert ErrorsLeverageEngine.PositionMustLiveForMinDuration();
        }
    }

    function isMinPositionDurationPassed(uint256 nftId) internal view returns (bool) {
        return block.number >= positionLedger.getOpenBlock(nftId) + protocolParameters.getMinPositionDurationInBlocks();
    }

    function collectExitFeesAfterDebt(uint256 wbtcAmountAfterDebt) internal returns (uint256) {
        uint256 exitFee = protocolParameters.getExitFee();
        uint256 exitFeeAmount = wbtcAmountAfterDebt * exitFee / EXIT_FEE_BASE_DENOMINATOR;
        WBTC.transfer(protocolParameters.getFeeCollector(), exitFeeAmount);

        return exitFeeAmount;
    }

    function sendBalanceToUser(uint256 wbtcLeft, uint256 minWbtc) internal {
        if (wbtcLeft < minWbtc) {
            revert ErrorsLeverageEngine.NotEnoughTokensReceived();
        }
        WBTC.transfer(msg.sender, wbtcLeft);
    }

    function recordPositionClosed(uint256 nftId, uint256 finalUserBalance) internal {
        emit EventsLeverageEngine.PositionClosed(
            nftId, 
            msg.sender, 
            positionLedger.getStrategyAddress(nftId),
            finalUserBalance, 
            positionLedger.getDebtAmount(nftId)
        );

        positionLedger.setPositionState(nftId, PositionState.CLOSED);
        positionToken.burn(nftId);
    }
}
