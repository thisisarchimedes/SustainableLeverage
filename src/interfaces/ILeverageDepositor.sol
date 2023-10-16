// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

interface ILeverageDepositor {
    // Routes for swapping
    enum SwapRoute {
        WBTC,
        WBTCWETH_CURVE_TRIPOOL,
        WBTCWETH_UNISWAPV3_003
    }

    function deposit(address strategy, SwapRoute route, uint256 amount) external returns (uint256 receivedShares);
}
