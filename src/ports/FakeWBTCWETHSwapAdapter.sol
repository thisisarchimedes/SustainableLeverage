// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import "../interfaces/IERC20Detailed.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISwapAdapter } from "../interfaces/ISwapAdapter.sol";
import { ISwapRouterUniV3 } from "../interfaces/ISwapRouterUniV3.sol";

//TODO: Implement swap on different exchanges such as curvev2 pools and balancer
contract FakeWBTCWETHSwapAdapter is ISwapAdapter {
    IERC20 public wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address public leverageDepositor;

    uint256 public wbtcToWethExchangeRate;
    uint256 public wethToWbtcExchangeRate;

    constructor() { }

    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        address exchange,
        bytes calldata payload,
        SwapRoute route,
        address recipient
    )
        external
        payable
        returns (uint256 receivedAmount)
    {
        if (route == SwapRoute.UNISWAPV3) {
            receivedAmount = swapOnUniswapV3(fromToken, toToken, fromAmount, payload, recipient);
        }
    }

    function swapOnUniswapV3(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        bytes calldata payload,
        address recipient
    )
        internal
        returns (uint256 toTokenAmount)
    {
        if (fromToken == wbtc) {
            toTokenAmount = (fromAmount * wbtcToWethExchangeRate * 10 ** IERC20Detailed(address(toToken)).decimals())
                / 10 ** IERC20Detailed(address(fromToken)).decimals();
        } else {
            toTokenAmount = (fromAmount * wethToWbtcExchangeRate * 10 ** IERC20Detailed(address(toToken)).decimals())
                / 10 ** IERC20Detailed(address(fromToken)).decimals();
        }

        toToken.transfer(recipient, toTokenAmount);
    }

    function setWbtcToWethExchangeRate(uint256 rate) external {
        wbtcToWethExchangeRate = rate;
    }

    function setWethToWbtcExchangeRate(uint256 rate) external {
        wethToWbtcExchangeRate = rate;
    }
}
