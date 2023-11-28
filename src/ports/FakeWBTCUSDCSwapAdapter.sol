// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import "../interfaces/IERC20Detailed.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISwapAdapter } from "../interfaces/ISwapAdapter.sol";
import { ISwapRouterUniV3 } from "../interfaces/ISwapRouterUniV3.sol";

//TODO: Implement swap on different exchanges such as curvev2 pools and balancer
contract FakeWBTCUSDCSwapAdapter is ISwapAdapter {
    IERC20 public wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address public leverageDepositor;

    uint256 public wbtcToUsdcExchangeRate;
    uint256 public usdcToWbtcExchangeRate;

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
        uint256 ORACLE_DECIMALS = 8;
        uint256 total_decimals = IERC20Detailed(address(fromToken)).decimals() + IERC20Detailed(address(toToken)).decimals() + ORACLE_DECIMALS;
        total_decimals = total_decimals - IERC20Detailed(address(toToken)).decimals();
        if (fromToken == wbtc) {
            toTokenAmount =
                (fromAmount * wbtcToUsdcExchangeRate * 10 ** IERC20Detailed(address(toToken)).decimals()) / 10 ** total_decimals;
        } else {
            toTokenAmount =
                (fromAmount * usdcToWbtcExchangeRate * 10 ** IERC20Detailed(address(toToken)).decimals()) / 10 ** total_decimals;
        }

        toToken.transfer(recipient, toTokenAmount);
    }

    function setWbtcToUsdcExchangeRate(uint256 rate) external {
        wbtcToUsdcExchangeRate = rate;
    }

    function setUsdcToWbtcExchangeRate(uint256 rate) external {
        usdcToWbtcExchangeRate = rate;
    }
}
