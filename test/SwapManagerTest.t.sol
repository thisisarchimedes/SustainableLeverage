// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { SwapManager } from "src/SwapManager.sol";
import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract SwapManagerTest is BaseTest {
    using ErrorsLeverageEngine for *;

    ISwapAdapter uniswap;

    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork. blockNumber: 18_369_197
        vm.createSelectFork({ urlOrAlias: "mainnet" });
        initTestFramework();

        uniswap = allContracts.swapManager.getSwapAdapterForRoute(SwapManager.SwapRoute.UNISWAPV3);
    }

    function testShouldSwapWbtcToUsdcOnUniV3() external {
        uint256 wbtcAmountToSwap = 1e8;
        deal(WBTC, address(this), wbtcAmountToSwap);
        
        uint256 wbtcBalanceBefore = IERC20(WBTC).balanceOf(address(this));
        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(address(this));

        ISwapAdapter.SwapWbtcParams memory params = ISwapAdapter.SwapWbtcParams({
            otherToken: IERC20(USDC),
            fromAmount: wbtcAmountToSwap,
            payload: getUniswapWBTCUSDCPayload(),
            recipient: address(this)
        });
        IERC20(WBTC).transfer(address(uniswap), wbtcAmountToSwap);
        uniswap.swapFromWbtc(params);

        uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(this));
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(address(this));

        assertLt(wbtcBalanceAfter, wbtcBalanceBefore);
        assertGt(usdcBalanceAfter, usdcBalanceBefore);

        verifyThatNothingLeftOnSwapper(uniswap);
    }

    function getUniswapWBTCUSDCPayload() internal view returns (bytes memory) {
        return abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), USDC),
                deadline: block.timestamp + 100_000
            })
        );
    }

    function testShouldSwapUsdcToWBtcOnUniV3() external {

        uint256 usdcAmountToSwap = 1e8;
        deal(USDC, address(this), usdcAmountToSwap);

        uint256 wbtcBalanceBefore = IERC20(WBTC).balanceOf(address(this));
        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(address(this));

        ISwapAdapter.SwapWbtcParams memory params = ISwapAdapter.SwapWbtcParams({
            otherToken: IERC20(USDC),
            fromAmount: usdcAmountToSwap,
            payload: getUniswapUSDCWBTCPayload(),
            recipient: address(this)
        });
        IERC20(USDC).transfer(address(uniswap), usdcAmountToSwap);
        uniswap.swapToWbtc(params);

        uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(this));
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(address(this));

        assertGt(wbtcBalanceAfter, wbtcBalanceBefore);
        assertLt(usdcBalanceAfter, usdcBalanceBefore);

        verifyThatNothingLeftOnSwapper(uniswap);
    }

    function getUniswapUSDCWBTCPayload() internal view returns (bytes memory) {
        return abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(USDC, uint24(3000), WBTC),
                deadline: block.timestamp + 100_000
            })
        );
    }

    function verifyThatNothingLeftOnSwapper(ISwapAdapter swapAdapter) internal {
        assertEq(IERC20(WBTC).balanceOf(address(swapAdapter)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapAdapter)), 0);
        assertEq(IERC20(WETH).balanceOf(address(swapAdapter)), 0);
        assertEq(address(swapAdapter).balance, 0);
    }
}
/*

Test List

[X] Can swap to BTC on Uniswap (after contract sends token with transfer) - without validting price
[X] Can swap from BTC on Uniswap (after contract sends WBTC with transfer)
[] Swap and check against oracle
[] Can swap to BTC with fake swapper (after contract sends token with transfer)
[] Can swap from BTC with fake swapper (after contract sends WBTC with transfer)
[] Only previliaged can swap

*/
