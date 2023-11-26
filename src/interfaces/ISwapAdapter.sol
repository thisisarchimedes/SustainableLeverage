// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//TODO: Implement swap on different exchanges such as curvev2 pools and balancer
interface ISwapAdapter {
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
        returns (uint256 receivedAmount);
}
