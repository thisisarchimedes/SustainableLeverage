// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";

/// @title StrategyManager Contract
/// @notice Only supports WBTC as collateral and borrowing asset
contract ProtocolParameters is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    // Fee (taken from profits) taken after returning all debt during exit by user in
    // 10000 (For example: 50 is 0.5%)
    uint256 private exitFee = 50;

    // Address that collects fees
    address private feeCollector;

    // TODO: Change back to 12 - Cool down period for user in blocks
    // before allowing close position
    uint8 private minPositionDurationInBlocks = 0;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setExitFee(uint256 fee) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        exitFee = fee;
        emit EventsLeverageEngine.ExitFeeUpdated(fee);
    }

    function setFeeCollector(address collector) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        feeCollector = collector;
        emit EventsLeverageEngine.FeeCollectorUpdated(collector);
    }

    function setMinPositionDurationInBlocks(uint8 blockCount) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        if (blockCount <= 1) {
            revert ErrorsLeverageEngine.BlockCountTooLow();
        }
        if (blockCount >= 6400) {
            revert ErrorsLeverageEngine.BlockCountTooHigh();
        }
        minPositionDurationInBlocks = blockCount;
    }

    function getExitFee() external view returns (uint256) {
        return exitFee;
    }

    function getFeeCollector() external view returns (address) {
        return feeCollector;
    }

    function getMinPositionDurationInBlocks() external view returns (uint8) {
        return minPositionDurationInBlocks;
    }
}
