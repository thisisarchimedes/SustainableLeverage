// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity ^0.8.18;

import "../src/LvBTC.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/utils/math/Math.sol";

import "test/BaseTest.sol";
import { IWBTCVault } from "../src/interfaces/IWBTCVault.sol";
import { ICurvePool } from "src/interfaces/ICurvePool.sol";
import "forge-std/console.sol";
import { console2 } from "forge-std/console2.sol";

contract LvBTCTest is BaseTest {
    int128 private immutable WBTC_INDEX = 0;
    int128 private immutable LVBTC_INDEX = 1;
    address private LVBTC_ADMIN_ADDRESS = 0x93B435e55881Ea20cBBAaE00eaEdAf7Ce366BeF2;

    function setUp() public {
        initFork();
        initTestFramework();

        mintLvBTCToSelf();

        // deposit to curve pool
        ERC20(WBTC).approve(address(allContracts.lvBTCCurvePool), type(uint256).max);
        ERC20(allContracts.lvBTC).approve(address(allContracts.lvBTCCurvePool), type(uint256).max);

        allContracts.lvBTC.transfer(address(allContracts.wbtcVault), 1e8);
        deal(WBTC, address(this), 1000e8);

        // Initialize WBTC Vault and other necessary components
        deal(WBTC, address(allContracts.wbtcVault), 1000e8);

        deal(WBTC, address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496), 100e8);
        allContracts.lvBTC.transfer(address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496), 100e8); //TODO:check

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10e8;
        amounts[1] = 50e8;
        ICurvePool(allContracts.lvBTCCurvePool).add_liquidity(amounts, 0);

        allContracts.wbtcVault.setlvBTCPoolAddress(address(allContracts.lvBTCCurvePool));
    }

    function mintLvBTCToSelf() internal {
        uint256 amountToMint = 5000e8;

        //mint and sell lvBTC to curve pool
        address deployerAddress = address(this);

        vm.startPrank(LVBTC_ADMIN_ADDRESS);
        allContracts.lvBTC.addMinter(LVBTC_ADMIN_ADDRESS);
        allContracts.lvBTC.setMintDestination(deployerAddress);
        allContracts.lvBTC.mint(5000e8);
        allContracts.lvBTC.setMintDestination(address(allContracts.wbtcVault));

        vm.stopPrank();

        assert(allContracts.lvBTC.balanceOf(address(this)) == amountToMint);
        assert(allContracts.lvBTC.totalSupply() == amountToMint);
    }

    function testDepositToCurvePool() public {
        // Example test using depositToCurvePool from CurvePoolManagement
        depositToCurvePool(1e8, 1e8);
    }

    function calculateLVBTCToSellToBalancePool() public view returns (uint256) {
        uint256 wbtcBalance = allContracts.lvBTCCurvePool.balances(0);
        uint256 lvBtcBalance = allContracts.lvBTCCurvePool.balances(1);

        // Calculate the desired WBTC balance after balancing the pool
        uint256 k = wbtcBalance * lvBtcBalance;
        uint256 desiredWbtcBalance = Math.sqrt(k);

        // Calculate the amount of LVBTC to sell using the ratio of desiredWbtcBalance to wbtcBalance
        uint256 lvBtcToSell = lvBtcBalance - Math.mulDiv(lvBtcBalance, desiredWbtcBalance, wbtcBalance);

        return lvBtcToSell;
    }

    function depositToCurvePool(uint256 wbtcAmount, uint256 lvBtcAmount) internal {
        ERC20(WBTC).approve(address(allContracts.lvBTCCurvePool), wbtcAmount);
        allContracts.lvBTC.approve(address(allContracts.lvBTCCurvePool), lvBtcAmount);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = wbtcAmount;
        amounts[1] = lvBtcAmount;

        ICurvePool(allContracts.lvBTCCurvePool).add_liquidity(amounts, 0);
    }

    // test that we dont have enough lvBTC -> call mint -> call swap lvBTC to WBTC and burn the remaining lvBTC in the
    // contract.

    function testSwapBigAmountOfLvBTCToWBTC() public {
        uint256 lvBTCBalance = allContracts.lvBTC.balanceOf(address(allContracts.wbtcVault));

        vm.expectRevert(ErrorsLeverageEngine.NotEnoughLvBTC.selector);
        allContracts.wbtcVault.swaplvBTCtoWBTC(lvBTCBalance * 2, 1);
    }

    function testSendWBTCFromVaultToCurvePool() public {
        uint256 wbtcBalanceBefore = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
        uint256 lvBTCTotalSupplyBefore = allContracts.lvBTC.totalSupply();

        uint256 minAmount = allContracts.lvBTCCurvePool.get_dy(WBTC_INDEX, LVBTC_INDEX, wbtcBalanceBefore / 2);

        //deduct 1% slippage
        minAmount -= minAmount / 100;

        uint256 wbtcbalanceBeforePool = IERC20(WBTC).balanceOf(address(allContracts.lvBTCCurvePool));

        allContracts.wbtcVault.swapWBTCtolvBTC(wbtcBalanceBefore / 2, minAmount);
        uint256 lvBTCTotalSupplyAfter = allContracts.lvBTC.totalSupply();

        uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
        uint256 wbtcbalanceAfterPool = IERC20(WBTC).balanceOf(address(allContracts.lvBTCCurvePool));

        assertGt(wbtcBalanceBefore * 98 / 100, wbtcBalanceAfter);
        assertGt(lvBTCTotalSupplyBefore, lvBTCTotalSupplyAfter);
        assertGt(wbtcbalanceAfterPool, wbtcbalanceBeforePool);
    }

    function testMintLVBTCAndBuyWBTCFromPool() public {
        deal(WBTC, address(this), 5000e8);

        //unbalance the pool
        ICurvePool(address(allContracts.lvBTCCurvePool)).exchange(WBTC_INDEX, LVBTC_INDEX, 20e8, 1);

        //get unbalanced values
        uint256 wbtcInPoolBefore = allContracts.lvBTCCurvePool.balances(0);
        uint256 lvBtcInPoolBefore = allContracts.lvBTCCurvePool.balances(1);
        uint256 wbtcInVaultBefore = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));

        //calculate number of lvBTC to mint and sell to the pool
        uint256 numberToSell = calculateLVBTCToSellToBalancePool();

        //mint and sell lvBTC to curve pool
        vm.startPrank(LVBTC_ADMIN_ADDRESS);
        allContracts.lvBTC.addMinter(address(this));
        allContracts.lvBTC.setMintDestination(address(allContracts.wbtcVault));
        vm.stopPrank();

        uint256 lvBTCTotalSupplyBefore = allContracts.lvBTC.totalSupply();

        allContracts.lvBTC.mint(numberToSell);

        uint256 minAmount = allContracts.lvBTCCurvePool.get_dy(LVBTC_INDEX, WBTC_INDEX, numberToSell);

        allContracts.wbtcVault.swaplvBTCtoWBTC(numberToSell, minAmount);

        uint256 wbtcInVaultAfter = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));

        //get balances after
        uint256 wbtInPooleAfter = allContracts.lvBTCCurvePool.balances(0);
        uint256 lvBtcInPoolAfter = allContracts.lvBTCCurvePool.balances(1);

        uint256 lvBTCTotalSupplyAfter = allContracts.lvBTC.totalSupply();

        assertGt(wbtcInVaultAfter, wbtcInVaultBefore);
        assertGt(lvBtcInPoolAfter, lvBtcInPoolBefore);
        assertGt(wbtcInPoolBefore, wbtInPooleAfter);
        assertGt(lvBTCTotalSupplyAfter, lvBTCTotalSupplyBefore);
    }

    function calculatePoolTokensRatio(uint256 balance0, uint256 balance1) public pure returns (uint256) {
        return balance0 * 1000 / balance1;
    }
}
