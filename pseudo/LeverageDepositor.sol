// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title LeverageDepositor Contract
/// @notice This contract facilitates the swapping between WBTC and WETH (or USDC in future) and interacts with strategies.
contract LeverageDepositor  {

    // ERC20 interface for WBTC and WETH (or USDC)
    IERC20 internal wbtc;
    IERC20 internal weth; // (or usdc in future)

    // Routes for swapping
    enum SwapRoute {
        WBTC,
        WBTCWETH_CURVE_TRIPOOL,
        WBTCWETH_UNISWAPV3_003,
        // Add more routes as needed
    }

    constructor(address _wbtc, address _weth) {
        wbtc = IERC20(_wbtc);
        weth = IERC20(_weth);
    }

    /// @notice Deposit WBTC and optionally swap to WETH before depositing into strategy
    /// @param strategy Address of the strategy to deposit into.
    /// @param route The route to use for swapping.
    /// @param amount Amount of WBTC to deposit.
    function deposit(address strategy, SwapRoute route, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount should be greater than 0");

        // Transfer WBTC from sender to this contract
        wbtc.transferFrom(msg.sender, address(this), amount);

        if (route == SwapRoute.WBTCWETH_CURVE_TRIPOOL) {
            // Code to swap WBTC to WETH using Curve TriPool
            // After swapping, you should have WETH in this contract
        } else if (route == SwapRoute.WBTCWETH_UNISWAPV3_003) {
            // Code to swap WBTC to WETH using Uniswap V3 with 0.3% fee
            // After swapping, you should have WETH in this contract
        } // Add more routes as needed

        // Despoit WETH to strategy
    }



    /// @notice Redeem from strategy and optionally swap WETH to WBTC
    /// @param strategy Address of the strategy to withdraw from.
    /// @param route The route to use for swapping back.
    /// @param shares Shares to withdraw from strategy.
    function redeem(address strategy, SwapRoute route, uint256 shares) external onlyOwner {
        require(shares > 0, "Shares should be greater than 0");


        if (route == SwapRoute.WBTCWETH_CURVE_TRIPOOL) {
            // Code to swap WETH to WBTC using Curve TriPool
        } else if (route == SwapRoute.WBTCWETH_UNISWAPV3_003) {
            // Code to swap WETH to WBTC using Uniswap V3 with 0.3% fee
        } // Add more routes as needed

        // Redeem and transfer WBTC to sender
       
    }
}
