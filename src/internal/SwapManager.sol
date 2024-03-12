// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";

import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";

contract SwapManager is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    mapping(SwapRoute => ISwapAdapter) internal swapAdapter;

    enum SwapRoute {
        UNISWAPV3
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setSwapAdapter(SwapRoute route, ISwapAdapter adapter) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        swapAdapter[route] = adapter;
    }

    function getSwapAdapterForRoute(SwapRoute route) external view returns (ISwapAdapter) {
        ISwapAdapter adapter = swapAdapter[route];
        if (address(adapter) == address(0)) revert ErrorsLeverageEngine.SwapAdapterNotSet();
        return adapter;
    }
}
