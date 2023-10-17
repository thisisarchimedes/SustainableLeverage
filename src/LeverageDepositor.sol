// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ILeverageDepositor } from "./interfaces/ILeverageDepositor.sol";
import { IMultiPoolStrategy } from "./interfaces/IMultiPoolStrategy.sol";

/// @title LeverageDepositor Contract
/// @notice This contract facilitates the swapping between WBTC and WETH (or USDC in future) and interacts with
/// strategies.
contract LeverageDepositor is ILeverageDepositor {
    // ERC20 interface for WBTC and WETH (or USDC)
    IERC20 internal wbtc;
    IERC20 internal weth; // (or usdc in future)

    // Add more routes as needed
    constructor(address _wbtc, address _weth) {
        wbtc = IERC20(_wbtc);
        weth = IERC20(_weth);
    }

    /// @notice Deposit WBTC and optionally swap to WETH before depositing into strategy
    /// @param strategy Address of the strategy to deposit into.
    /// @param amount Amount of WBTC to deposit.
    // TODO - add access control
    function deposit(
        address strategy,
        address strategyAsset,
        uint256 amount
    )
        external
        returns (uint256 receivedShares)
    {
        require(amount > 0, "Amount should be greater than 0");
        // Despoit WETH to strategy
        IERC20(strategyAsset).approve(strategy, amount);
        receivedShares = IMultiPoolStrategy(strategy).deposit(amount, address(this));
    }

    /// @notice Redeem from strategy and optionally swap WETH to WBTC
    /// @param strategy Address of the strategy to withdraw from.
    /// @param shares Shares to withdraw from strategy.
    /// TODO : ADD ACCESS CONTROL
    function redeem(address strategy, uint256 shares) external {
        require(shares > 0, "Shares should be greater than 0");
        // Redeem from strategy
    }
}
