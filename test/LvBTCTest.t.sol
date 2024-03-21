// // SPDX-License-Identifier: CC BY-NC-ND 4.0
// pragma solidity >=0.8.21 <0.9.0;

// import "../src/LvBTC.sol";
// import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
// import "openzeppelin-contracts/utils/math/Math.sol";

// import "test/BaseTest.sol";
// import { BaseCurvePoolTest } from "./BaseCurvePoolTest.sol"; // Adjust path as necessary;
// import { IWBTCVault } from "../src/interfaces/IWBTCVault.sol";
// import { ICurvePool } from "src/interfaces/ICurvePool.sol";
// import "forge-std/console.sol";

// contract LvBTCTest is BaseCurvePoolTest {
//     int128 private immutable WBTC_INDEX = 0;
//     int128 private immutable LVBTC_INDEX = 1;

//     function setUp() public {
//         initFork();
//         initTestFramework();

//         // deposit to curve pool
//         ERC20(WBTC).approve(address(allContracts.lvBTCCurvePool), type(uint256).max);
//         ERC20(allContracts.lvBTC).approve(address(allContracts.lvBTCCurvePool), type(uint256).max);

//         vm.prank(address(allContracts.wbtcVault));
//         allContracts.lvBTC.mint(address(this), 1000e8);

//         deal(WBTC, address(this), 1000e8);

//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = 1e8;
//         amounts[1] = 5e8;
//         ICurvePool(allContracts.lvBTCCurvePool).add_liquidity(amounts, 0);

//         // Initialize WBTC Vault and other necessary components
//         deal(WBTC, address(allContracts.wbtcVault), 10e8);
//     }

//     function testDepositToCurvePool() public {
//         // Example test using depositToCurvePool from CurvePoolManagement
//         depositToCurvePool(100e8, 100e8);
//     }

//     function calculateLVBTCToSellToBalancePool() public view returns (uint256) {
//         uint256 wbtcBalance = allContracts.lvBTCCurvePool.balances(0);
//         uint256 lvBtcBalance = allContracts.lvBTCCurvePool.balances(1);

//         // Calculate the desired WBTC balance after balancing the pool
//         uint256 k = wbtcBalance * lvBtcBalance;
//         uint256 desiredWbtcBalance = Math.sqrt(k);

//         // Calculate the amount of LVBTC to sell using the ratio of desiredWbtcBalance to wbtcBalance
//         uint256 lvBtcToSell = lvBtcBalance - Math.mulDiv(lvBtcBalance, desiredWbtcBalance, wbtcBalance);

//         return lvBtcToSell;
//     }

//     function depositToCurvePool(uint256 wbtcAmount, uint256 lvBtcAmount) internal {
//         ERC20(WBTC).approve(address(allContracts.lvBTCCurvePool), wbtcAmount);
//         ERC20(allContracts.lvBTC).approve(address(allContracts.lvBTCCurvePool), lvBtcAmount);

//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = wbtcAmount;
//         amounts[1] = lvBtcAmount;

//         ICurvePool(allContracts.lvBTCCurvePool).add_liquidity(amounts, 0);
//     }

//     function testSendWBTCFromVaultToCurvePool() public {
//         uint256 wbtcBalanceBefore = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
//         uint256 lvBTCTotalSupplyBefore = allContracts.lvBTC.totalSupply();

//         console.log("**** SEND WBTC FROM VAULT TO CURVE ****");
//         console.log("LVBTC total supply before:", lvBTCTotalSupplyBefore);

//         console.log("WBTC Vault balance:", wbtcBalanceBefore);

//         uint256 minAmount = allContracts.lvBTCCurvePool.get_dy(WBTC_INDEX, LVBTC_INDEX, wbtcBalanceBefore / 2);

//         //deduct 1% slippage
//         minAmount -= minAmount / 100;

//         uint256 wbtcbalanceBeforePool = IERC20(WBTC).balanceOf(address(allContracts.lvBTCCurvePool));
//         console.log("WBTC in curve pool before:", wbtcbalanceBeforePool);

//         allContracts.wbtcVault.swapToLVBTC(wbtcBalanceBefore / 2, minAmount);
//         console.log("******************");
//         uint256 lvBTCTotalSupplyAfter = allContracts.lvBTC.totalSupply();
//         console.log("LVBTC total supply after:", lvBTCTotalSupplyAfter);

//         uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
//         uint256 wbtcbalanceAfterPool = IERC20(WBTC).balanceOf(address(allContracts.lvBTCCurvePool));
//         console.log("WBTC Vault balance after:", wbtcBalanceAfter);
//         console.log("WBTC in curve pool after:", wbtcbalanceAfterPool);

//         assertGt(wbtcBalanceBefore * 98 / 100, wbtcBalanceAfter);
//         assertGt(lvBTCTotalSupplyBefore, lvBTCTotalSupplyAfter);
//         assertGt(wbtcbalanceAfterPool, wbtcbalanceBeforePool);

//         console.log("*****************");
//     }

//     function testMintLVBTCAndBuyWBTCFromPool() public {
//         deal(WBTC, address(this), 5000e8);

//         console.log("**** MINT LVBTC AND BUY WBTC FROM CURVE ****");

//         //unbalance the pool
//         ICurvePool(address(allContracts.lvBTCCurvePool)).exchange(WBTC_INDEX, LVBTC_INDEX, 20e8, 1);

//         //get unbalanced values
//         uint256 wbtcInPoolBefore = allContracts.lvBTCCurvePool.balances(0);
//         uint256 lvBtcInPoolBefore = allContracts.lvBTCCurvePool.balances(1);
//         uint256 wbtcInVaultBefore = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));

//         console.log("WBTC in vault before:", wbtcInVaultBefore);

//         console.log("WBTC in curve pool before:", wbtcInPoolBefore);

//         console.log("LVBTC in curve pool before:", lvBtcInPoolBefore);

//         //calculate number of lvBTC to mint and sell to the pool
//         uint256 numberToSell = calculateLVBTCToSellToBalancePool();

//         console.log("**** Minting and selling LVBTC to curve pool ****");

//         uint256 lvBTCTotalSupplyBefore = allContracts.lvBTC.totalSupply();
//         uint256 minAmount = allContracts.lvBTCCurvePool.get_dy(LVBTC_INDEX, WBTC_INDEX, numberToSell);

//         //mint and sell lvBTC to curve pool
//         allContracts.wbtcVault.swapToWBTC(numberToSell, minAmount);

//         uint256 wbtcInVaultAfter = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));

//         //get balances after
//         uint256 wbtInPooleAfter = allContracts.lvBTCCurvePool.balances(0);
//         uint256 lvBtcInPoolAfter = allContracts.lvBTCCurvePool.balances(1);
//         console.log("WBTC in vault after:", wbtcInVaultAfter);
//         console.log("WBTC in curve pool after:", wbtInPooleAfter);
//         console.log("LVBTC in curve pool after:", lvBtcInPoolAfter);

//         uint256 lvBTCTotalSupplyAfter = allContracts.lvBTC.totalSupply();

//         assertGt(wbtcInVaultAfter, wbtcInVaultBefore);
//         assertGt(lvBtcInPoolAfter, lvBtcInPoolBefore);
//         assertGt(wbtcInPoolBefore, wbtInPooleAfter);
//         assertGt(lvBTCTotalSupplyAfter, lvBTCTotalSupplyBefore);
//     }

//     function calculatePoolTokensRatio(uint256 balance0, uint256 balance1) public pure returns (uint256) {
//         return balance0 * 1000 / balance1;
//     }
// }
