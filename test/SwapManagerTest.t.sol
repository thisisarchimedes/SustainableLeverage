// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { SwapManager } from "src/SwapManager.sol";
import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";
import { FakeWBTCUSDCSwapAdapter } from "src/ports/swap_adapters/FakeWBTCUSDCSwapAdapter.sol";
import { FakeWBTCWETHSwapAdapter } from "src/ports/swap_adapters/FakeWBTCWETHSwapAdapter.sol";

contract SwapManagerTest is BaseTest {
    using ErrorsLeverageEngine for *;

    ISwapAdapter uniswapV3Adapter;
    FakeWBTCUSDCSwapAdapter fakeWBTCUSDCAdapter;

    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        vm.createSelectFork({ urlOrAlias: "mainnet" });
        initTestFramework();

        uniswapV3Adapter = allContracts.swapManager.getSwapAdapterForRoute(SwapManager.SwapRoute.UNISWAPV3);

        fakeWBTCUSDCAdapter = new FakeWBTCUSDCSwapAdapter();
        deal(USDC, address(fakeWBTCUSDCAdapter), 1_000_000_000 * (10 ** ERC20(USDC).decimals()));
        deal(WBTC, address(fakeWBTCUSDCAdapter), 1_000_000_000 * (10 ** ERC20(WBTC).decimals()));
    }

    function testShouldSwapWbtcToUsdconFakeSwapper() external {
        uint256 wbtcAmountToSwap = 1 * (10 ** ERC20(WBTC).decimals());
        deal(WBTC, address(this), wbtcAmountToSwap);

        uint256 wbtcToUsdcExchangeRate = 10_000 * (10 ** ERC20(USDC).decimals());
        fakeWBTCUSDCAdapter.setWbtcToUsdcExchangeRate(wbtcToUsdcExchangeRate);

        swapWbtcToUsdcOnFake(wbtcAmountToSwap);                

        uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(this));
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(address(this));

        uint256 expectedUsdcAmount = (wbtcAmountToSwap * wbtcToUsdcExchangeRate) / (10 ** ERC20(USDC).decimals());
        assertEq(wbtcBalanceAfter, 0);
        assertEq(usdcBalanceAfter, expectedUsdcAmount);
    }

    function swapWbtcToUsdcOnFake(uint256 wbtcAmountToSwap) internal {
        ISwapAdapter.SwapWbtcParams memory params = ISwapAdapter.SwapWbtcParams({
            otherToken: IERC20(USDC),
            fromAmount: wbtcAmountToSwap,
            payload: getUniswapWBTCUSDCPayload(),
            recipient: address(this)
        });
        IERC20(WBTC).transfer(address(fakeWBTCUSDCAdapter), wbtcAmountToSwap);
        fakeWBTCUSDCAdapter.swapFromWbtc(params);
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
