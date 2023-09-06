pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ZapperLeverage {
    using SafeMath for uint256;

    IERC20 internal wbtc;
    IERC20 internal weth;
    IStrategy internal strategy; // The actual strategy interface
    ICurveSwap internal curve;   // The Curve Tricrypto swap interface

    constructor(IERC20 _wbtc, IERC20 _weth, IStrategy _strategy, ICurveSwap _curve) {
        wbtc = _wbtc;
        weth = _weth;
        strategy = _strategy;
        curve = _curve;
    }

    function totalAssets() external view override returns (uint256) {
        return strategy.totalAssets();
    }

    function deposit(uint256 assets, address receiver) external override returns (uint256 shares) {
        // Swap WBTC for WETH
        uint256 wethAmount = curve.swapWBTCForWETH(assets);

        // Deposit WETH into the strategy
        shares = strategy.deposit(wethAmount, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner, uint minimumReceive) external override returns (uint256) {
        // Withdraw WETH from the strategy
        uint256 wethReceived = strategy.withdraw(assets, address(this), owner, minimumReceive);

        // Swap WETH for WBTC
        uint256 wbtcReceived = curve.swapWETHForWBTC(wethReceived);

        // Send WBTC back to LeverageEngine (or the specified receiver)
        wbtc.transfer(receiver, wbtcReceived);
        
        return wbtcReceived;
    }

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
