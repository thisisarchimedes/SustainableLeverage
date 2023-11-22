// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
import "./helpers/OracleTestHelper.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { ILeverageEngine } from "src/interfaces/ILeverageEngine.sol";
import { FakeOracle } from "../src/ports/FakeOracle.sol";
import { FakeWBTCWETHSwapAdapter } from "../src/ports/FakeWBTCWETHSwapAdapter.sol";

import { FakeOracle } from "src/ports/FakeOracle.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract LiquidatePositionTest is BaseTest {
    /* solhint-disable  */
    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 18_369_197 });
        _prepareContracts();
        deal(WBTC, address(wbtcVault), 100e8);
    }

    function testSetLiquidationBufferPerStrategyTo10And15PercentAbove() external {
        uint256 newLiquidationBuffer;
        ILeverageEngine.StrategyConfig memory strategyConfig;

        strategyConfig.quota = 100e8;
        strategyConfig.positionLifetime = 1000;
        strategyConfig.maximumMultiplier = 3e8;
        strategyConfig.liquidationFee = 0.02e8;

        newLiquidationBuffer = 1.1 * 10 ** 8; // 10%
        strategyConfig.liquidationBuffer = newLiquidationBuffer;
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        strategyConfig = leverageEngine.getStrategyConfig(ETHPLUSETH_STRATEGY);
        assertEq(newLiquidationBuffer, strategyConfig.liquidationBuffer);

        newLiquidationBuffer = 1.15 * 10 ** 8; // 15%
        strategyConfig.liquidationBuffer = newLiquidationBuffer;
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        strategyConfig = leverageEngine.getStrategyConfig(ETHPLUSETH_STRATEGY);
        assertEq(newLiquidationBuffer, strategyConfig.liquidationBuffer);
    }

    function testSetLiquidationFees() external {
        uint256 newLiquidationFee;
        ILeverageEngine.StrategyConfig memory strategyConfig;

        strategyConfig.quota = 100e8;
        strategyConfig.positionLifetime = 1000;
        strategyConfig.maximumMultiplier = 3e8;
        strategyConfig.liquidationBuffer = 1.1e8;

        newLiquidationFee = 0.02e8; // 2%
        strategyConfig.liquidationFee = newLiquidationFee;
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        strategyConfig = leverageEngine.getStrategyConfig(ETHPLUSETH_STRATEGY);
        assertEq(newLiquidationFee, strategyConfig.liquidationFee);

        newLiquidationFee = 0.05e8; // 5%
        strategyConfig.liquidationFee = newLiquidationFee;
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        strategyConfig = leverageEngine.getStrategyConfig(ETHPLUSETH_STRATEGY);
        assertEq(newLiquidationFee, strategyConfig.liquidationFee);
    }

    function testWBTCPositionValueForUSDCPosition() external {
        uint256 collateralAmount = 5e8;
        uint256 borrowAmount = 15e8;
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(500), WETH, uint24(3000), USDC),
                deadline: block.timestamp + 1000
            })
        );

        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(leverageEngine), 10e8);

        uint256 nftId = leverageEngine.openPosition(
            collateralAmount,
            borrowAmount,
            FRAXBPALUSD_STRATEGY,
            0,
            SwapAdapter.SwapRoute.UNISWAPV3,
            payload,
            address(0)
        );

        uint256 positionValueInWBTC = leverageEngine.previewPositionValueInWBTC(nftId);
        uint256 delta = (collateralAmount + borrowAmount) * 200 / 10_000; // 2% delta
        assertAlmostEq(collateralAmount + borrowAmount, positionValueInWBTC, delta);
    }

    function testWBTCPositionValueForWETHPosition() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );

        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(leverageEngine), 10e8);
        uint256 nftId = leverageEngine.openPosition(
            collateralAmount, borrowAmount, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );

        uint256 positionValueInWBTC = leverageEngine.previewPositionValueInWBTC(nftId);
        uint256 delta = (collateralAmount + borrowAmount) * 200 / 10_000; // 2% delta
        assertAlmostEq(collateralAmount + borrowAmount, positionValueInWBTC, delta);
    }

    function testIsPositionNotLiquidatable() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );

        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(leverageEngine), 10e8);
        uint256 nftId = leverageEngine.openPosition(
            collateralAmount, borrowAmount, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );

        assertEq(leverageEngine.isPositionLiquidatable(nftId), false);
    }

    function testIsPositionLiquidatable() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );

        deal(WBTC, address(this), 1000e8);
        ERC20(WBTC).approve(address(leverageEngine), type(uint256).max);
        uint256 nftId = leverageEngine.openPosition(
            collateralAmount, borrowAmount, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );

        assertEq(leverageEngine.isPositionLiquidatable(nftId), false);

        FakeOracle fakeETHUSDOracle = new FakeOracle();
        fakeETHUSDOracle.updateFakePrice(100e8);
        fakeETHUSDOracle.updateDecimals(8);
        leverageEngine.setOracle(WETH, fakeETHUSDOracle);

        assertEq(leverageEngine.isPositionLiquidatable(nftId), true);
    }

    function testIsPositionLiquidatableRevertsOnClosedPosition() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        // open position

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );

        deal(WBTC, address(this), 1000e8);
        ERC20(WBTC).approve(address(leverageEngine), type(uint256).max);
        uint256 nftId = leverageEngine.openPosition(
            collateralAmount, borrowAmount, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );

        // close position

        bytes memory payloadClose = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000
            })
        );
        leverageEngine.closePosition(nftId, 0, SwapAdapter.SwapRoute.UNISWAPV3, payloadClose, address(0));

        vm.expectRevert(LeverageEngine.PositionNotLive.selector);
        leverageEngine.isPositionLiquidatable(nftId);
    }

    function testIsPositionLiquidatableRevertsOnNonExistingNFT() external {
        vm.expectRevert(LeverageEngine.PositionNotLive.selector);
        leverageEngine.isPositionLiquidatable(999);
    }

    function testLiquditionRevertsIfPositionIsClosed() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        // open position

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );

        deal(WBTC, address(this), 1000e8);
        ERC20(WBTC).approve(address(leverageEngine), type(uint256).max);
        uint256 nftId = leverageEngine.openPosition(
            collateralAmount, borrowAmount, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );

        // close position

        bytes memory payloadClose = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000
            })
        );
        leverageEngine.closePosition(nftId, 0, SwapAdapter.SwapRoute.UNISWAPV3, payloadClose, address(0));

        vm.expectRevert(LeverageEngine.PositionNotLive.selector);
        leverageEngine.liquidatePosition(nftId, 0, SwapAdapter.SwapRoute.UNISWAPV3, payloadClose, address(0));
    }

    function testLiquidationOfETHBasedPosition() external {
        // Set liquidateion Buffer
        uint256 liquidationFee = 0.02e8;
        ILeverageEngine.StrategyConfig memory strategyConfig = ILeverageEngine.StrategyConfig({
            quota: 100e8,
            maximumMultiplier: 3e8,
            positionLifetime: 1000,
            liquidationBuffer: 1.1e8,
            liquidationFee: liquidationFee
        });
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);

        // Deposit
        uint256 nftId = openETHBasedPosition(10e8, 30e8);

        uint256 fakeEthUsdPrice = 0;
        uint256 fakeBtcEthPrice = 0;
        uint256 fakeBtcUsdPrice = 0;

        {
            // Get current eth price
            (, int256 ethUsdPrice,,,) = ethUsdOracle.latestRoundData();
            (, int256 btcEthPrice,,,) = btcEthOracle.latestRoundData();
            (, int256 wtbcUsdPrice,,,) = wbtcUsdOracle.latestRoundData();

            // Drop the eth price by 20%
            fakeEthUsdPrice = (uint256(ethUsdPrice) * 0.8e8) / 1e8; // USD
            fakeBtcEthPrice = (uint256(btcEthPrice) * 1.2e8) / 1e8; // ETH
            fakeBtcUsdPrice = (uint256(wtbcUsdPrice) * 1.2e8) / 1e8;

            FakeWBTCWETHSwapAdapter fakeSwapAdapter = new FakeWBTCWETHSwapAdapter();
            deal(WETH, address(fakeSwapAdapter), 1000e18);
            deal(WBTC, address(fakeSwapAdapter), 1000e8);
            fakeSwapAdapter.setWbtcToWethExchangeRate(fakeBtcEthPrice);
            fakeSwapAdapter.setWethToWbtcExchangeRate(1e36 / fakeBtcEthPrice);
            leverageEngine.changeSwapAdapter(address(fakeSwapAdapter));
        }

        {
            FakeOracle fakeETHUSDOracle = new FakeOracle();
            fakeETHUSDOracle.updateFakePrice(fakeEthUsdPrice);
            fakeETHUSDOracle.updateDecimals(8);
            leverageEngine.setOracle(WETH, fakeETHUSDOracle);
            FakeOracle fakeWBTCUSDOracle = new FakeOracle();
            fakeWBTCUSDOracle.updateFakePrice(fakeBtcUsdPrice);
            fakeWBTCUSDOracle.updateDecimals(8);
            leverageEngine.setOracle(WBTC, fakeWBTCUSDOracle);
        }

        uint256 debtPaidBack;
        {
            // Liquidate position
            uint256 wbtcVaultBalanceBefore = IERC20(WBTC).balanceOf(address(wbtcVault));
            leverageEngine.liquidatePosition(
                nftId, 0, SwapAdapter.SwapRoute.UNISWAPV3, getWBTCWETHUniswapPayload(), address(0)
            );
            uint256 wbtcVaultBalanceAfter = IERC20(WBTC).balanceOf(address(wbtcVault));
            debtPaidBack = wbtcVaultBalanceAfter - wbtcVaultBalanceBefore;
        }

        uint256 positionValueInWBTC = leverageEngine.previewPositionValueInWBTC(nftId);
        PositionLedgerLib.LedgerEntry memory position = leverageEngine.getPosition(nftId);

        assertEq(position.wbtcDebtAmount, debtPaidBack);

        uint256 delta = (debtPaidBack + position.claimableAmount) * 200 / 10_000; // 2% delta
        assertAlmostEq(
            debtPaidBack + position.claimableAmount,
            positionValueInWBTC - liquidationFee * position.claimableAmount / 1e8,
            delta
        );
    }

    function openETHBasedPosition(uint256 collateralAmount, uint256 borrowAmount) internal returns (uint256 nftId) {
        bytes memory payload = getWBTCWETHUniswapPayload();

        deal(WBTC, address(this), 1000e8);
        ERC20(WBTC).approve(address(leverageEngine), type(uint256).max);
        nftId = leverageEngine.openPosition(
            collateralAmount, borrowAmount, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
    }

    function getWBTCWETHUniswapPayload() internal view returns (bytes memory payload) {
        payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );
    }
}
