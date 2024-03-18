// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IERC20Detailed } from "src/interfaces/IERC20Detailed.sol";

import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";
import { Constants } from "src/libs/Constants.sol";

contract FakeWBTCWETHSwapAdapter is ISwapAdapter {
    using Constants for *;

    IERC20 public wbtc = IERC20(Constants.WBTC_ADDRESS);
    address public leverageDepositor;

    uint256 public wbtcToWethExchangeRate;
    uint256 public wethToWbtcExchangeRate;

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
        // solhint-disable-next-line
        bytes calldata payload,
        address recipient
    )
        internal
        returns (uint256 toTokenAmount)
    {
        if (fromToken == wbtc) {
            toTokenAmount =
                (fromAmount * wbtcToWethExchangeRate * 10 ** IERC20Detailed(address(toToken)).decimals()) / 10 ** 26;
        } else {
            toTokenAmount =
                (fromAmount * wethToWbtcExchangeRate * 10 ** IERC20Detailed(address(toToken)).decimals()) / 10 ** 36;
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
