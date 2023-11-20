// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISwapRouterUniV3 } from "./interfaces/ISwapRouterUniV3.sol";
import { IQuoter } from "./interfaces/IQuoter.sol";

//TODO: Implement swap on different exchanges such as curvev2 pools and balancer
contract SwapAdapter {
    IERC20 immutable wbtc;
    address public leverageDepositor;
    address constant UNISWAPV3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant UNISWAPV3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;

    constructor(address _wbtc, address _leverageDepositor) {
        wbtc = IERC20(_wbtc);
        leverageDepositor = _leverageDepositor;
    }

    struct UniswapV3Data {
        bytes path;
        uint256 deadline;
    }

    enum SwapRoute { UNISWAPV3 }

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
        returns (uint256 receivedAmount)
    {
        UniswapV3Data memory data = abi.decode(payload, (UniswapV3Data));

        fromToken.approve(UNISWAPV3_ROUTER, fromAmount);
        uint256 balanceBefore = toToken.balanceOf(recipient);
        ISwapRouterUniV3(UNISWAPV3_ROUTER).exactInput(
            ISwapRouterUniV3.ExactInputParams({
                path: data.path,
                recipient: recipient,
                deadline: data.deadline,
                amountIn: fromAmount,
                amountOutMinimum: 1
            })
        );
        receivedAmount = toToken.balanceOf(recipient) - balanceBefore;
    }

    function estimateSwap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        bytes calldata payload,
        SwapRoute route
    )
        external
        view
        returns (uint256 estimatedAmount)
    {
        if (route == SwapRoute.UNISWAPV3) {
            estimatedAmount = estimateSwapOnUniswapV3(fromToken, toToken, fromAmount, payload);
        }
    }

    function estimateSwapOnUniswapV3(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        bytes calldata payload
    )
        internal
        view
        returns (uint256 estimatedAmount)
    {
        UniswapV3Data memory data = abi.decode(payload, (UniswapV3Data));

        estimatedAmount = IQuoter(UNISWAPV3_QUOTER).quoteExactInput(data.path, fromAmount);
    }
}
