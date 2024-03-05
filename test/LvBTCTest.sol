// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import "../src/LvBTC.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "test/BaseTest.sol";
import { BaseCurvePoolTest } from "./BaseCurvePoolTest.sol"; // Adjust path as necessary;
import { console2 } from "forge-std/console2.sol";
import { IWBTCVault } from "../src/interfaces/IWBTCVault.sol";
import { ICurvePool } from "src/interfaces/ICurvePool.sol";

contract LvBTCTest is BaseCurvePoolTest {
    function setUp() public {
        initFork(); // Make sure to implement this in your base or here if specific to this test
        initTestFramework(); // Ensure this is implemented according to your test setup

        // deposit to curve pool
        ERC20(WBTC).approve(address(allContracts.lvBTCCurvePool), type(uint256).max);
        ERC20(allContracts.lvBTC).approve(address(allContracts.lvBTCCurvePool), type(uint256).max);

        console2.log(address(allContracts.lvBTC));
        deal(WBTC, address(this), 1000e8);
        deal(address(allContracts.lvBTC), address(this), 1000e8);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e8;
        amounts[1] = 100e8;
        ICurvePool(allContracts.lvBTCCurvePool).add_liquidity(amounts, 0);

        // Initialize WBTC Vault and other necessary components
        deal(WBTC, address(allContracts.wbtcVault), 10e8);
    }

    function testDepositToCurvePool() public {
        // Example test using depositToCurvePool from CurvePoolManagement
        depositToCurvePool(100e8, 100e8);
    }

    function depositToCurvePool(uint256 wbtcAmount, uint256 lvBtcAmount) internal {
        ERC20(WBTC).approve(address(allContracts.lvBTCCurvePool), wbtcAmount);
        ERC20(allContracts.lvBTC).approve(address(allContracts.lvBTCCurvePool), lvBtcAmount);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = wbtcAmount;
        amounts[1] = lvBtcAmount;

        ICurvePool(allContracts.lvBTCCurvePool).add_liquidity(amounts, 0); // Assuming minMintAmount is not a concern
            // for the tests.
    }

    function testCurvePoolBalanced() public {
        // uint256 wbtcBalance = pool.balances(0);
        // uint256 lvBtcBalance = pool.balances(1);

        // uint256 ratio = calculatePoolTokensRatio(lvBtcBalance, wbtcBalance);

        // assert(ratio == 1000);
    }

    function testSendWBTCFromVaultToCurvePool() public {
        uint256 wbtcBalanceBefore = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
        uint256 wbtcbalanceBeforePool = IERC20(WBTC).balanceOf(address(allContracts.lvBTCCurvePool));
        allContracts.wbtcVault.swapToLVBTC(wbtcBalanceBefore, 1); //TBD get dy from curve pool
        uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
        uint256 wbtcbalanceAfterPool = IERC20(WBTC).balanceOf(address(allContracts.lvBTCCurvePool));

        assertGt(wbtcBalanceBefore * 98 / 100, wbtcBalanceAfter);
        assertGt(wbtcbalanceAfterPool, wbtcbalanceBeforePool);
    }

    function calculatePoolTokensRatio(uint256 balance0, uint256 balance1) public pure returns (uint256) {
        return balance0 * 1000 / balance1;
    }
}

/*

- When Pool is low on WBTC:
    [] Send WBTC from the vault to the pool (swap WBTC>>lvBTC)
    [] Burn the lvBTC we got for the WBTC
- When there is extra WBTC in the pool, get WBTC from the pool to the vault:
    [] Mint lvBTC and send it to the vault
    [] Swap lvBTC>>WBTC

*/
