pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title ZapperLeverage
/// @dev This contract acts as an intermediary between the LeverageEngine and the actual strategy.
/// It manages the conversions between WBTC and WETH as needed, making the interaction seamless for the LeverageEngine.
contract ZapperLeverage {
    using SafeMath for uint256;

    IERC20 internal wbtc;
    IERC20 internal weth;
    IStrategy internal strategy; // The actual strategy interface
    ICurveSwap internal curve;   // The Curve Tricrypto swap interface

    /// @dev Constructor for initializing the LeverageZapper.
    /// @param _wbtc The address of the WBTC token.
    /// @param _weth The address of the WETH token.
    /// @param _strategy The address of the actual strategy.
    /// @param _curve The address of the Curve Tricrypto swap contract.
    constructor(IERC20 _wbtc, IERC20 _weth, IStrategy _strategy, ICurveSwap _curve) {
        wbtc = _wbtc;
        weth = _weth;
        strategy = _strategy;
        curve = _curve;
    }

    /// @notice Fetches the total assets managed by the strategy.
    /// @return The total assets value.
    function totalAssets() external view override returns (uint256) {
        return strategy.totalAssets();
    }

    /// @notice Allows a user to deposit assets into the strategy via the zapper.
    /// @param assets Amount of WBTC to deposit.
    /// @param receiver The address that will receive the strategy shares.
    /// @return shares The number of strategy shares received.
    function deposit(uint256 assets, address receiver) external override returns (uint256 shares) {
        // Swap WBTC for WETH
        uint256 wethAmount = curve.swapWBTCForWETH(assets);

        // Deposit WETH into the strategy
        shares = strategy.deposit(wethAmount, receiver);
    }

    /// @notice Withdraws assets from the strategy using the zapper.
    /// @param assets Amount of WBTC to withdraw.
    /// @param receiver The address that will receive the withdrawn WBTC.
    /// @param owner The owner of the strategy shares being redeemed.
    /// @param minimumReceive The minimum amount of WBTC expected to receive.
    /// @return The amount of WBTC withdrawn.
    function withdraw(uint256 assets, address receiver, address owner, uint minimumReceive) external override returns (uint256) {
        // Withdraw WETH from the strategy
        uint256 wethReceived = strategy.withdraw(assets, address(this), owner, minimumReceive);

        // Swap WETH for WBTC
        uint256 wbtcReceived = curve.swapWETHForWBTC(wethReceived);

        // Send WBTC back to LeverageEngine (or the specified receiver)
        wbtc.transfer(receiver, wbtcReceived);
        
        return wbtcReceived;
    }

    /// @notice Redeems strategy shares for WBTC using the zapper.
    /// @param shares Number of strategy shares to redeem.
    /// @param receiver The address that will receive the redeemed WBTC.
    /// @param owner The owner of the strategy shares being redeemed.
    /// @param minimumReceive The minimum amount of WBTC expected to receive.
    /// @return The amount of WBTC redeemed.
    function redeem(uint256 shares, address receiver, address owner, uint minimumReceive) external override returns (uint256) {
        // Redeem shares for WETH
        uint256 wethReceived = strategy.redeem(shares, address(this), owner, minimumReceive);

        // Swap WETH for WBTC
        uint256 wbtcReceived = curve.swapWETHForWBTC(wethReceived);

        // Send WBTC back to LeverageEngine (or the specified receiver)
        wbtc.transfer(receiver, wbtcReceived);
        
        return wbtcReceived;
    }
}
