// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";
import { ISwapRouterUniV3 } from "src/interfaces/ISwapRouterUniV3.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { Constants } from "src/libs/Constants.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";

contract UniV3SwapAdapter is ISwapAdapter, AccessControl {
    using ProtocolRoles for *;
    using Constants for *;

    IERC20 internal constant WBTC = IERC20(Constants.WBTC_ADDRESS);

    constructor() {
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ProtocolRoles.INTERNAL_CONTRACT_ROLE, ProtocolRoles.ADMIN_ROLE);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionOpener);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionCloser);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionLiquidator);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionExpirator);
    }

    struct UniswapV3Data {
        bytes path;
        uint256 deadline;
        uint256 amountOutMin;
    }

    // NOTICE: Assumes WBTC already sent to this contract
    function swapToWbtc(SwapWbtcParams calldata params)
        external
        onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE)
        returns (uint256)
    {
        uint256 balanceBefore = WBTC.balanceOf(params.recipient);

        swapOnUniswapV3(params.otherToken, params.fromAmount, params.payload, params.recipient);

        return WBTC.balanceOf(params.recipient) - balanceBefore;
    }

    // NOTICE: Assumes tokens already sent to this contract
    function swapFromWbtc(SwapWbtcParams calldata params)
        external
        onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE)
        returns (uint256)
    {
        uint256 balanceBefore = params.otherToken.balanceOf(params.recipient);

        swapOnUniswapV3(WBTC, params.fromAmount, params.payload, params.recipient);

        return params.otherToken.balanceOf(params.recipient) - balanceBefore;
    }

    function swapOnUniswapV3(
        IERC20 fromToken,
        uint256 fromAmount,
        bytes calldata payload,
        address recipient
    )
        internal
    {
        UniswapV3Data memory data = abi.decode(payload, (UniswapV3Data));

        fromToken.approve(Constants.UNISWAPV3_ROUTER_ADDRESS, fromAmount);

        ISwapRouterUniV3(Constants.UNISWAPV3_ROUTER_ADDRESS).exactInput(
            ISwapRouterUniV3.ExactInputParams({
                path: data.path,
                recipient: recipient,
                deadline: data.deadline,
                amountIn: fromAmount,
                amountOutMinimum: data.amountOutMin
            })
        );
    }
}
