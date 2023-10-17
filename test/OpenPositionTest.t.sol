// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import "./BaseTest.sol";
/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract OpenPositionTest is PRBTest, StdCheats, BaseTest {
    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 18_369_197 });
        _prepareContracts();
        deal(WBTC, address(wbtcVaultMock), 100e8);
        deal(WETH, address(leverageDepositor), 1000e18);
    }

    function test_ShouldRevertWithArithmeticOverflow() external {
        vm.expectRevert();
        leverageEngine.openPosition(5e18, 5e18, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, "", address(0));
    }

    function test_ShouldRevertWithExceedBorrowLimit() external {
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, 100e8, 1000, 3e8, 1.25e8);
        vm.expectRevert(LeverageEngine.ExceedBorrowLimit.selector);
        leverageEngine.openPosition(5e8, 80e8, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, "", address(0));
    }

    function test_ShouldAbleToOpenPos() external {
        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(leverageEngine), 10e8);
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, 100e8, 1000, 3e8, 1.25e8);
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );
        leverageEngine.openPosition(
            5e8, 15e8, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
        PositionLedgerLib.LedgerEntry memory position = leverageEngine.getPosition(0);
        assertEq(position.collateralAmount, 5e8);
        assertEq(position.wbtcDebtAmount, 15e8);
    }
}
