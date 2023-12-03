// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract SwapAdapterTest is BaseTest {
    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 18_369_197 });
        initTestFramework();
        deal(WBTC, address(this), 100e8);
    }

    function test_ShouldSwapOnUniV3() external {
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );
        IERC20(WBTC).transfer(address(allContracts.swapAdapter), 1e8);
        uint256 wethBalanceBefore = IERC20(WETH).balanceOf(address(allContracts.leverageDepositor));
        allContracts.swapAdapter.swap(
            IERC20(WBTC),
            IERC20(WETH),
            1e8,
            address(allContracts.swapAdapter),
            payload,
            SwapAdapter.SwapRoute.UNISWAPV3,
            address(allContracts.leverageDepositor)
        );
        uint256 wethBalanceAfter = IERC20(WETH).balanceOf(address(allContracts.leverageDepositor));
        assertGt(wethBalanceAfter - wethBalanceBefore, 0);
    }
}
