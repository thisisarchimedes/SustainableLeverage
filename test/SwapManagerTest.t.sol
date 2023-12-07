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

    ISwapAdapter uniswapV3Adapter;

    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork. blockNumber: 18_369_197
        vm.createSelectFork({ urlOrAlias: "mainnet" });
        initTestFramework();

        uniswapV3Adapter = allContracts.swapManager.getSwapAdapterForRoute(SwapManager.SwapRoute.UNISWAPV3);
    }

    function testShouldSwapWbtcToUsdcOnUniV3() external {
        uint256 wbtcAmountToSwap = 1 * (10 ** ERC20(WBTC).decimals());
        deal(WBTC, address(this), wbtcAmountToSwap);

        uint256 wbtcBalanceBefore = IERC20(WBTC).balanceOf(address(this));
        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(address(this));

        swapWbtcToUsdcOnUniswapV3(wbtcAmountToSwap);

        uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(this));
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(address(this));

        assertLt(wbtcBalanceAfter, wbtcBalanceBefore);
        assertGt(usdcBalanceAfter, usdcBalanceBefore);

        verifyThatNothingLeftOnSwapper(uniswapV3Adapter);
    }

    function swapWbtcToUsdcOnUniswapV3(uint256 wbtcAmountToSwap) internal {
        ISwapAdapter.SwapWbtcParams memory params = ISwapAdapter.SwapWbtcParams({
            otherToken: IERC20(USDC),
            fromAmount: wbtcAmountToSwap,
            payload: getUniswapWBTCUSDCPayload(),
            recipient: address(this)
        });
        IERC20(WBTC).transfer(address(uniswapV3Adapter), wbtcAmountToSwap);
        uniswapV3Adapter.swapFromWbtc(params);
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
        uint256 usdcAmountToSwap = 100_000 * (10 ** ERC20(USDC).decimals());
        deal(USDC, address(this), usdcAmountToSwap);

        uint256 wbtcBalanceBefore = IERC20(WBTC).balanceOf(address(this));
        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(address(this));

        swapUsdcToWbtcOnUniswapV3(usdcAmountToSwap);

        uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(this));
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(address(this));

        assertGt(wbtcBalanceAfter, wbtcBalanceBefore);
        assertLt(usdcBalanceAfter, usdcBalanceBefore);

        verifyThatNothingLeftOnSwapper(uniswapV3Adapter);
    }

    function swapUsdcToWbtcOnUniswapV3(uint256 usdcAmountToSwap) internal {
        ISwapAdapter.SwapWbtcParams memory params = ISwapAdapter.SwapWbtcParams({
            otherToken: IERC20(USDC),
            fromAmount: usdcAmountToSwap,
            payload: getUniswapUSDCWBTCPayload(),
            recipient: address(this)
        });
        IERC20(USDC).transfer(address(uniswapV3Adapter), usdcAmountToSwap);
        uniswapV3Adapter.swapToWbtc(params);
    }

    function getUniswapUSDCWBTCPayload() internal view returns (bytes memory) {
        return abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(USDC, uint24(3000), WBTC),
                deadline: block.timestamp + 100_000
            })
        );
    }

    function testSwapOfWbtcToUsdcOnUniV3AndOracle() external {
        uint256 wbtcAmountToSwap = 10 * (10 ** ERC20(WBTC).decimals());
        deal(WBTC, address(this), wbtcAmountToSwap);

        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(address(this));
        swapWbtcToUsdcOnUniswapV3(wbtcAmountToSwap);         
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(address(this));

        uint256 expectedUsdcAmount = getOracleWbtcAmountUsdcValue(wbtcAmountToSwap);

        uint256 delta = expectedUsdcAmount * 2_500 / 100_000;
        assertAlmostEq(expectedUsdcAmount, usdcBalanceAfter - usdcBalanceBefore, delta);
    }

    function getOracleWbtcAmountUsdcValue(uint256 wbtcAmount) internal view returns(uint256) { 

        uint256 totalDecimals = allContracts.oracleManager.getOracleDecimals(WBTC) + ERC20(WBTC).decimals() - ERC20(USDC).decimals();
        return allContracts.oracleManager.getLatestPrice(WBTC) * wbtcAmount / 10 ** (totalDecimals);
    }

    function testSwapOfUsdcToWbtcOnUniV3AndOracle() external {
        uint256 usdcAmountToSwap = 420_000 * (10 ** ERC20(USDC).decimals());
        deal(USDC, address(this), usdcAmountToSwap);

        uint256 wbtcBalanceBefore = IERC20(WBTC).balanceOf(address(this));
        swapUsdcToWbtcOnUniswapV3(usdcAmountToSwap);
        uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(this));

        uint256 expectedWbtcAmount = getOracleUsdcAmountWbtcValue(usdcAmountToSwap);

        uint256 delta = expectedWbtcAmount * 2_500 / 100_000;
        assertAlmostEq(expectedWbtcAmount, wbtcBalanceAfter - wbtcBalanceBefore, delta);
    }

    function getOracleUsdcAmountWbtcValue(uint256 usdcAmount) internal view returns(uint256) { 

        uint256 totalDecimals = allContracts.oracleManager.getOracleDecimals(WBTC) + ERC20(WBTC).decimals() - ERC20(USDC).decimals();
        return (usdcAmount * 10 ** totalDecimals) / allContracts.oracleManager.getLatestPrice(WBTC);
    }

    function verifyThatNothingLeftOnSwapper(ISwapAdapter swapAdapter) internal {
        assertEq(IERC20(WBTC).balanceOf(address(swapAdapter)), 0);
        assertEq(IERC20(USDC).balanceOf(address(swapAdapter)), 0);
        assertEq(IERC20(WETH).balanceOf(address(swapAdapter)), 0);
        assertEq(address(swapAdapter).balance, 0);
    }
}

/*
// WBTC decimals: 8
// USDc decimals: 6

Test List

[X] Can swap to BTC on Uniswap (after contract sends token with transfer) - without validting price
[X] Can swap from BTC on Uniswap (after contract sends WBTC with transfer)
[X] repeat these ^ two tests just verify with price oracle
[] Can swap to BTC with fake swapper (after contract sends token with transfer)
[] Can swap from BTC with fake swapper (after contract sends WBTC with transfer)
[] Only previliaged can swap

*/
