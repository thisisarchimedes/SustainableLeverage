// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IERC20Detailed } from "src/interfaces/IERC20Detailed.sol";
import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";

//TODO: Implement swap on different exchanges such as curvev2 pools and balancer
contract FakeWBTCUSDCSwapAdapter is ISwapAdapter {
    IERC20 public wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 public usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address public leverageDepositor;

    uint256 public wbtcToUsdcExchangeRate;
    uint256 public usdcToWbtcExchangeRate;

    uint256 public constant FAKE_ORACLE_DECIMALS = 8;

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
        uint256 totalDecimals =
            IERC20Detailed(address(toToken)).decimals() + IERC20Detailed(address(fromToken)).decimals();

        if (fromToken == wbtc) {
            toTokenAmount =
                ((fromAmount * wbtcToUsdcExchangeRate) * (10 ** FAKE_ORACLE_DECIMALS)) / (10 ** totalDecimals);
        } else {
            toTokenAmount =
                ((fromAmount * usdcToWbtcExchangeRate) * (10 ** FAKE_ORACLE_DECIMALS)) / (10 ** totalDecimals);
        }

        toToken.transfer(recipient, toTokenAmount);

        return toTokenAmount;
    }

    function setWbtcToUsdcExchangeRate(uint256 rate) external {
        wbtcToUsdcExchangeRate = rate;
    }

    function setUsdcToWbtcExchangeRate(uint256 rate) external {
        usdcToWbtcExchangeRate = rate;
    }
}
