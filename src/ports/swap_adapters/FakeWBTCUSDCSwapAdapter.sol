// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/interfaces/IERC20Detailed.sol";
import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";
import { ISwapRouterUniV3 } from "src/interfaces/ISwapRouterUniV3.sol";
import { SwapManager } from "src/SwapManager.sol";

//TODO: Implement swap on different exchanges such as curvev2 pools and balancer
contract FakeWBTCUSDCSwapAdapter is ISwapAdapter {
    IERC20 public wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address public leverageDepositor;

    uint256 public wbtcToUsdcExchangeRate;
    uint256 public usdcToWbtcExchangeRate;

    constructor() { }

    function swapToWbtc(SwapWbtcParams calldata params) external returns (uint256) {
         return swap(params.otherToken, wbtc, params.fromAmount, params.payload, params.recipient);

    }

    function swapFromWbtc(SwapWbtcParams calldata params) external returns (uint256) {
        return swap(wbtc, params.otherToken, params.fromAmount, params.payload, params.recipient);

    }


    function swap(
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
        uint256 total_decimals = IERC20Detailed(address(fromToken)).decimals()
            + IERC20Detailed(address(toToken)).decimals() + ORACLE_DECIMALS;
        total_decimals = total_decimals - IERC20Detailed(address(toToken)).decimals();
        if (fromToken == wbtc) {
            toTokenAmount = (fromAmount * wbtcToUsdcExchangeRate * 10 ** IERC20Detailed(address(toToken)).decimals())
                / 10 ** total_decimals;
        } else {
            toTokenAmount = (fromAmount * usdcToWbtcExchangeRate * 10 ** IERC20Detailed(address(toToken)).decimals())
                / 10 ** total_decimals;
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
