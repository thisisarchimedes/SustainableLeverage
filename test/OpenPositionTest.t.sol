// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
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
        deal(WBTC, address(wbtcVault), 100e8);
    }

    function test_ShouldRevertWithArithmeticOverflow() external {
        vm.expectRevert();
        positionOpener.openPosition(5e18, 5e18, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, "", address(0));
    }

    function test_ShouldRevertWithExceedBorrowLimit() external {
        vm.expectRevert(ErrorsLeverageEngine.ExceedBorrowLimit.selector);
        positionOpener.openPosition(5e8, 80e8, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, "", address(0));
    }

    function test_ShouldAbleToOpenPosForWETHStrategy() external {
        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(positionOpener), 10e8);

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );
        positionOpener.openPosition(
            5e8, 15e8, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
        LedgerEntry memory position = positionLedger.getPosition(0);
        assertEq(position.collateralAmount, 5e8);
        assertEq(position.wbtcDebtAmount, 15e8);
    }

    function test_ShouldAbleToOpenPosForUSDCStrategy() external {
        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(positionOpener), 10e8);

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(500), WETH, uint24(3000), USDC),
                deadline: block.timestamp + 1000
            })
        );
        positionOpener.openPosition(
            5e8, 15e8, FRAXBPALUSD_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
        LedgerEntry memory position = positionLedger.getPosition(0);
        assertEq(position.collateralAmount, 5e8);
        assertEq(position.wbtcDebtAmount, 15e8);
    }

    function test_oracleDoesntReturnZero() external {

        uint256 ethUsd = oracleManager.getLatestPrice(WETH);
        assertGt(ethUsd, 0);

        uint256 wbtcUsd = oracleManager.getLatestPrice(WBTC);
        assertGt(wbtcUsd, 0);
    }

    function test_DetectPoolManipulation() external {
        // TODO flash loan attack - bend pool then open position. get far more
    }
}
