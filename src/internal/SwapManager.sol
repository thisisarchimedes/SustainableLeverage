// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";

import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";

contract SwapManager is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    IERC20 internal constant wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    mapping(SwapRoute => ISwapAdapter) internal swapAdapter;

    enum SwapRoute { UNISWAPV3 }

    constructor() {
    }

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setSwapAdapter(SwapRoute route, ISwapAdapter adapter) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        swapAdapter[route] = adapter;
    }

    function getSwapAdapterForRoute(SwapRoute route) external view returns (ISwapAdapter) {
        return swapAdapter[route];
    }
}
