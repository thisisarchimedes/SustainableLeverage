// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import "test/BaseTest.sol";

import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";

import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract OpenPositionTest is BaseTest {
    /* solhint-disable  */

    using ErrorsLeverageEngine for *;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        initFork();
        initTestFramework();

        deal(WBTC, address(allContracts.wbtcVault), 1000e8);
    }

    function test_ShouldRevertWithArithmeticOverflow() external {

        bytes memory payload = getWBTCWETHUniswapPayload();
        OpenPositionParams memory params = OpenPositionParams({
            collateralAmount: 5e18,
            wbtcToBorrow: 5e18,
            minStrategyShares: 0,
            strategy: ETHPLUSETH_STRATEGY,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });
         
        vm.expectRevert();
        allContracts.positionOpener.openPosition(params);
    }

    function test_ShouldRevertWithExceedBorrowLimit() external {

        uint256 multiplier = allContracts.leveragedStrategy.getMaximumMultiplier(ETHPLUSETH_STRATEGY);
        uint256 collateralAmount = 5e8;
        uint256 wbtcToBorrow = collateralAmount * (multiplier + 1);

        bytes memory payload = getWBTCWETHUniswapPayload();
        OpenPositionParams memory params = OpenPositionParams({
            collateralAmount: collateralAmount,
            wbtcToBorrow: wbtcToBorrow,
            minStrategyShares: 0,
            strategy: ETHPLUSETH_STRATEGY,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });
        vm.expectRevert(ErrorsLeverageEngine.ExceedBorrowLimit.selector);
        allContracts.positionOpener.openPosition(params);
    }

    function test_ShouldAbleToOpenPositionForWETHStrategy() external {
        ERC20(WBTC).approve(address(allContracts.positionOpener), 10e8);

        uint256 nftId = openETHBasedPosition(5e8, 15e8);

        assertEq(nftId, 0);
        LedgerEntry memory position = allContracts.positionLedger.getPosition(nftId);

        assertEq(position.collateralAmount, 5e8);
        assertEq(position.wbtcDebtAmount, 15e8);
    }

    function test_ShouldAbleToOpenPositionForUSDCStrategy() external {
        deal(WBTC, address(this), 100e8);
        ERC20(WBTC).approve(address(allContracts.positionOpener), type(uint256).max);

        uint256 nftId = openUSDCBasedPosition(5e8, 15e8);

        assertEq(nftId, 0);
        LedgerEntry memory position = allContracts.positionLedger.getPosition(nftId);

        assertEq(position.collateralAmount, 5e8);
        assertEq(position.wbtcDebtAmount, 15e8);
    }

    function test_PositionStateisLIVE() external {
        deal(WBTC, address(this), 100e8);
        ERC20(WBTC).approve(address(allContracts.positionOpener), type(uint256).max);

        uint256 nftId = openUSDCBasedPosition(5e8, 15e8);

        if (allContracts.positionLedger.getPositionState(nftId) != PositionState.LIVE) {
            revert("Position state isn't LIVE");
        }
    }

    function test_oracleDoesntReturnZero() external {

        uint256 ethUsd = allContracts.oracleManager.getLatestTokenPriceInUSD(WETH);
        assertGt(ethUsd, 0);

        uint256 wbtcUsd = allContracts.oracleManager.getLatestTokenPriceInUSD(WBTC);
        assertGt(wbtcUsd, 0);
    }

    function test_DetectPoolManipulation() external {
        // TODO flash loan attack - bend pool then open position. get far more
    }

    function test_previewOpenPositionETHStrategy() external {

        OpenPositionParams memory params = OpenPositionParams({
            collateralAmount: 5e8,
            wbtcToBorrow: 15e8,
            minStrategyShares: 0,
            strategy: ETHPLUSETH_STRATEGY,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: getWBTCWETHUniswapPayload(),
            exchange: address(0) 
        });
        uint256 previewShareNumber = allContracts.positionOpener.previewOpenPosition(params);
    
        uint256 nftId = openETHBasedPosition(5e8, 15e8);
        uint256 actualShareNumber = allContracts.positionLedger.getStrategyShares(nftId);

        uint256 delta = previewShareNumber * 2e8 / 100e8;
        assertAlmostEq(previewShareNumber, actualShareNumber, delta);
    }

    function test_previewOpenPositionUSDCStrategy() external {

        OpenPositionParams memory params = OpenPositionParams({
            collateralAmount: 5e8,
            wbtcToBorrow: 15e8,
            minStrategyShares: 0,
            strategy: FRAXBPALUSD_STRATEGY,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: getWBTCUSDCUniswapPayload(),
            exchange: address(0) 
        });
        uint256 previewShareNumber = allContracts.positionOpener.previewOpenPosition(params);
    
        uint256 nftId = openUSDCBasedPosition(5e8, 15e8);
        uint256 actualShareNumber = allContracts.positionLedger.getStrategyShares(nftId);

        uint256 delta = previewShareNumber * 2e8 / 100e8;
        assertAlmostEq(previewShareNumber, actualShareNumber, delta);
    }

}
