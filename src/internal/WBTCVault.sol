// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { EventsLeverageEngine } from "../libs/EventsLeverageEngine.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { IWBTCVault } from "src/interfaces/IWBTCVault.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { Constants } from "src/libs/Constants.sol";

contract WBTCVault is IWBTCVault, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;

    IERC20 public wbtc;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);

        wbtc = IERC20(Constants.WBTC_ADDRESS);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionOpener);
    }

    function borrowAmountTo(
        uint256 amount,
        address to
    )
        external
        override
        onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE)
    {
        wbtc.transfer(to, amount);
    }

    function repayDebt(uint256 nftId, uint256 amount) external {
        wbtc.safeTransferFrom(msg.sender, address(this), amount);
        emit EventsLeverageEngine.Repay(nftId, amount);
    }
}
