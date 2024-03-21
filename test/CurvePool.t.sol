// // SPDX-License-Identifier: CC BY-NC-ND 4.0
// pragma solidity >=0.8.21 <0.9.0;

// import "../src/LvBTC.sol";
// import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
// import { BaseCurvePoolTest } from "./BaseCurvePoolTest.sol"; // Ensure correct path
// import { ICurvePool } from "../src/interfaces/ICurvePool.sol";

// contract CurvePoolTest is BaseCurvePoolTest {
//     LVBTC private lvBTC;

//     function setUp() public {
//         initFork(); // Make sure to implement this in your base or here if specific to this test
//         initTestFramework(); // Ensure this is implemented according to your test setup

//         // vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/pLr2mJQRKzJGMLj5Df7ZhWyGjV-M7ZJI", 19_368_282);

//         // Deploy lvBTC
//         lvBTC = allContracts.lvBTC;

//         vm.prank(address(allContracts.wbtcVault));
//         lvBTC.mint(address(this), 1000e8);
//         deal(WBTC, address(this), 1000e8);
//     }

//     function prepareDeposit(uint256 wbtcAmount, uint256 lvBtcAmount) internal {
//         depositToCurvePool(wbtcAmount, lvBtcAmount);

//         uint256 lpTokenBalance = allContracts.lvBTCCurvePool.balanceOf(address(this));
//         assert(lpTokenBalance > 0);
//     }

//     function depositToCurvePool(uint256 wbtcAmount, uint256 lvBtcAmount) internal {
//         ERC20(WBTC).approve(address(allContracts.lvBTCCurvePool), wbtcAmount);
//         ERC20(allContracts.lvBTC).approve(address(allContracts.lvBTCCurvePool), lvBtcAmount);

//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = wbtcAmount;
//         amounts[1] = lvBtcAmount;

//         allContracts.lvBTCCurvePool.add_liquidity(amounts, 0); // Assuming minMintAmount is not a concern for the
// tests.
//     }

//     function testDeposit() public {
//         uint256 wbtcAmount = 100e8; // WBTC amount for deposit
//         uint256 lvBtcAmount = 200e8; // lvBTC amount for deposit

//         uint256 initialWbtcBalance = ERC20(WBTC).balanceOf(address(this));
//         uint256 initialLvBtcBalance = lvBTC.balanceOf(address(this));

//         prepareDeposit(wbtcAmount, lvBtcAmount);

//         uint256 lpTokenBalance = allContracts.lvBTCCurvePool.balanceOf(address(this));
//         assertTrue(lpTokenBalance > 0, "LP token balance should be greater than 0 after deposit");

//         // Additional checks
//         uint256 finalWbtcBalance = ERC20(WBTC).balanceOf(address(this));
//         uint256 finalLvBtcBalance = lvBTC.balanceOf(address(this));

//         // Check if the balances of WBTC and lvBTC decreased as expected
//         assertEq(
//             initialWbtcBalance - finalWbtcBalance, wbtcAmount, "WBTC balance didn't decrease by the deposit amount"
//         );
//         assertEq(
//             initialLvBtcBalance - finalLvBtcBalance, lvBtcAmount, "lvBTC balance didn't decrease by the deposit
// amount"
//         );

//         // Ensure the contract's balance of WBTC and lvBTC is as expected after the deposit
//         assertTrue(finalWbtcBalance == initialWbtcBalance - wbtcAmount, "Unexpected final WBTC balance");
//         assertTrue(finalLvBtcBalance == initialLvBtcBalance - lvBtcAmount, "Unexpected final lvBTC balance");
//     }

//     function testWithdraw() public {
//         uint256 wbtcAmount = 100e8; // WBTC amount for deposit
//         uint256 lvBtcAmount = 200e8; // lvBTC amount for deposit
//         // Ensure there's liquidity to withdraw by first depositing
//         prepareDeposit(wbtcAmount, lvBtcAmount);

//         uint256 initialWbtcBalance = ERC20(WBTC).balanceOf(address(this));
//         uint256 initialLvBtcBalance = lvBTC.balanceOf(address(this));
//         uint256 initialLpTokens = allContracts.lvBTCCurvePool.balanceOf(address(this));

//         uint256[] memory minAmounts = new uint256[](2);
//         minAmounts[0] = 50e8; // Example minimum amounts to avoid slippage issues
//         minAmounts[1] = 100e8;

//         // Withdraw liquidity
//         allContracts.lvBTCCurvePool.remove_liquidity(initialLpTokens, minAmounts);

//         uint256 finalWbtcBalance = ERC20(WBTC).balanceOf(address(this));
//         uint256 finalLvBtcBalance = lvBTC.balanceOf(address(this));
//         uint256 finalLpTokens = allContracts.lvBTCCurvePool.balanceOf(address(this));

//         // Verify that LP tokens were correctly burned/decreased
//         assertTrue(finalLpTokens < initialLpTokens, "LP tokens should decrease after withdrawal");

//         // Verify that WBTC and lvBTC balances increased as expected
//         assertTrue(finalWbtcBalance > initialWbtcBalance, "WBTC balance should increase after withdrawal");
//         assertTrue(finalLvBtcBalance > initialLvBtcBalance, "lvBTC balance should increase after withdrawal");
//     }

//     function testSwap() public {
//         uint256 wbtcAmount = 100e8; // WBTC amount for deposit
//         uint256 lvBtcAmount = 200e8; // lvBTC amount for deposit
//         // Ensure there's liquidity to withdraw by first depositing
//         prepareDeposit(wbtcAmount, lvBtcAmount);

//         uint256 wbtcAmountToSwap = 10e8; // Amount of WBTC to swap to lvBTC
//         uint256 initialWbtcBalance = ERC20(WBTC).balanceOf(address(this));
//         uint256 initialLvBtcBalance = lvBTC.balanceOf(address(this));

//         // Approve the pool to spend WBTC
//         ERC20(WBTC).approve(address(allContracts.lvBTCCurvePool), wbtcAmountToSwap);

//         // Perform the swap on the pool
//         uint256 minLvBtcAmount = 1; // Define a realistic minimum to avoid issues due to slippage
//         uint256 lvBtcAmountReceived = allContracts.lvBTCCurvePool.exchange(0, 1, wbtcAmountToSwap, minLvBtcAmount);

//         uint256 finalWbtcBalance = ERC20(WBTC).balanceOf(address(this));
//         uint256 finalLvBtcBalance = lvBTC.balanceOf(address(this));

//         // Assertions to verify the swap operation
//         assertTrue(
//             finalWbtcBalance == initialWbtcBalance - wbtcAmountToSwap, "WBTC balance decrease mismatch after swap"
//         );
//         assertTrue(
//             finalLvBtcBalance >= initialLvBtcBalance + lvBtcAmountReceived, "lvBTC balance increase mismatch after
// swap"
//         );
//         assertTrue(lvBtcAmountReceived >= minLvBtcAmount, "Received lvBTC amount less than the minimum expected");
//     }
// }
