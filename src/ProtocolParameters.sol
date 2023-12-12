// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ProtocolRoles } from "./libs/ProtocolRoles.sol";
import { ErrorsLeverageEngine } from "./libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "./libs/EventsLeverageEngine.sol";
import { DependencyAddresses } from "./libs/DependencyAddresses.sol";

/// @title StrategyManager Contract
/// @notice Only supports WBTC as collateral and borrowing asset
contract ProtocolParameters is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    uint256 private exitFee = 50; // Fee (taken from profits) taken after returning all debt during exit by user in 10000 (For example: 50 is 0.5%)
    address private feeCollector; // Address that collects fees
    uint8 private minPositionDurationInBlocks = 0; // TODO: Change back to 12 - Cool down period for user in blocks before allowing close position

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
        require(blockCount > 1, "Block count must be greater than 1");
        require(blockCount < 6_400, "Block count must be less than ~1 day");
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
