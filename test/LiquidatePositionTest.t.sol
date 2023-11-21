// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
import "./helpers/OracleTestHelper.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { FakeOracle } from "../src/ports/FakeOracle.sol";

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
        LeverageEngine.StrategyConfig memory strategyConfig;

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
        LeverageEngine.StrategyConfig memory strategyConfig;

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
}
