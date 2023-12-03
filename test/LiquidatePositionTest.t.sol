// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { ILeverageEngine } from "src/interfaces/ILeverageEngine.sol";
import { FakeOracle } from "../src/ports/FakeOracle.sol";
import { FakeWBTCWETHSwapAdapter } from "../src/ports/FakeWBTCWETHSwapAdapter.sol";
import { FakeOracle } from "src/ports/FakeOracle.sol";
import "./BaseTest.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";

contract LiquidatePositionTest is BaseTest {
    /* solhint-disable  */

    using ErrorsLeverageEngine for *;

    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 18_369_197 });
        initTestFramework();

        deal(WBTC, address(wbtcVault), 10_000_000e8);
        deal(WBTC, address(this), 10_000_000e8);
        ERC20(WBTC).approve(address(positionOpener), type(uint256).max);
        ERC20(WBTC).approve(address(positionCloser), type(uint256).max);

    }

    function testSetLiquidationBufferPerStrategyTo10And15PercentAbove() external {
        uint256 newLiquidationBuffer;
        LeveragedStrategy.StrategyConfig memory strategyConfig;

        strategyConfig.quota = 100e8;
        strategyConfig.positionLifetime = 1000;
        strategyConfig.maximumMultiplier = 3e8;
        strategyConfig.liquidationFee = 0.02e8;

        newLiquidationBuffer = 1.1 * 10 ** 8; // 10%
        strategyConfig.liquidationBuffer = newLiquidationBuffer;
        leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        assertEq(newLiquidationBuffer, leveragedStrategy.getLiquidationBuffer(ETHPLUSETH_STRATEGY));

        newLiquidationBuffer = 1.15 * 10 ** 8; // 15%
        strategyConfig.liquidationBuffer = newLiquidationBuffer;
        leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        assertEq(newLiquidationBuffer, leveragedStrategy.getLiquidationBuffer(ETHPLUSETH_STRATEGY));
    }

    function testSetLiquidationFees() external {
        uint256 newLiquidationFee;
        LeveragedStrategy.StrategyConfig memory strategyConfig;

        strategyConfig.quota = 100e8;
        strategyConfig.positionLifetime = 1000;
        strategyConfig.maximumMultiplier = 3e8;
        strategyConfig.liquidationBuffer = 1.1e8;

        newLiquidationFee = 0.02e8; // 2%
        strategyConfig.liquidationFee = newLiquidationFee;
        leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        assertEq(newLiquidationFee, leveragedStrategy.getLiquidationFee(ETHPLUSETH_STRATEGY));

        newLiquidationFee = 0.05e8; // 5%
        strategyConfig.liquidationFee = newLiquidationFee;
        leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        assertEq(newLiquidationFee, leveragedStrategy.getLiquidationFee(ETHPLUSETH_STRATEGY));
    }

    function testWBTCPositionValueForUSDCPosition() external {
        uint256 collateralAmount = 5e8;
        uint256 borrowAmount = 15e8;

        uint256 nftId = openUSDCBasedPosition(collateralAmount, borrowAmount);

        uint256 positionValueInWBTC = leveragedStrategy.previewPositionValueInWBTC(nftId);
        uint256 delta = (collateralAmount + borrowAmount) * 200 / 10_000; // 2% delta
        assertAlmostEq(collateralAmount + borrowAmount, positionValueInWBTC, delta);
    }

    function testWBTCPositionValueForWETHPosition() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);

        uint256 positionValueInWBTC = leveragedStrategy.previewPositionValueInWBTC(nftId);
        uint256 delta = (collateralAmount + borrowAmount) * 200 / 10_000; // 2% delta
        assertAlmostEq(collateralAmount + borrowAmount, positionValueInWBTC, delta);
    }

    function testIsPositionNotLiquidatable() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);

        assertEq(leveragedStrategy.isPositionLiquidatable(nftId), false);
    }

    function testIsPositionLiquidatable() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);

        assertEq(leveragedStrategy.isPositionLiquidatable(nftId), false);

        FakeOracle fakeETHUSDOracle = new FakeOracle();
        fakeETHUSDOracle.updateFakePrice(100e8);
        fakeETHUSDOracle.updateDecimals(8);
        oracleManager.setOracle(WETH, fakeETHUSDOracle);

        assertEq(leveragedStrategy.isPositionLiquidatable(nftId), true);
    }

    function testIsPositionLiquidatableRevertsOnClosedPosition() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);

        closeETHBasedPosition(nftId);

        vm.expectRevert(ErrorsLeverageEngine.PositionNotLive.selector);
        leveragedStrategy.isPositionLiquidatable(nftId);
    }

    function testIsPositionLiquidatableRevertsOnNonExistingNFT() external {
        vm.expectRevert(ErrorsLeverageEngine.PositionNotLive.selector);
        leveragedStrategy.isPositionLiquidatable(999_999);
    }

    function testLiquditionRevertsIfPositionIsClosed() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);

        closeETHBasedPosition(nftId);

        bytes memory payloadClose = getWETHWBTCUniswapPayload();

        positionCloser.setMonitor(address(this));

        vm.expectRevert(ErrorsLeverageEngine.PositionNotLive.selector);
        positionCloser.liquidatePosition(nftId, 0, SwapAdapter.SwapRoute.UNISWAPV3, payloadClose, address(0));
    }

    function testLiquidationOfETHBasedPosition() external {
        // Set liquidateion BufferLeveragedStrategy
        uint256 liquidationFee = 0.02e8;
        LeveragedStrategy.StrategyConfig memory strategyConfig = LeveragedStrategy.StrategyConfig({
            quota: 100e8,
            maximumMultiplier: 3e8,
            positionLifetime: 1000,
            liquidationBuffer: 1.1e8,
            liquidationFee: liquidationFee
        });
        leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);

        uint256 nftId = openETHBasedPosition(10e8, 30e8);

        uint256 feeCollectorBalanceBefore = ERC20(WBTC).balanceOf(address(feeCollector));
        uint256 debtPaidBack = liquidateETHPosition(nftId);
        uint256 feeCollectorBalanceAfter = ERC20(WBTC).balanceOf(address(feeCollector));

        uint256 positionValueInWBTC = leveragedStrategy.previewPositionValueInWBTC(nftId);
        LedgerEntry memory position = positionLedger.getPosition(nftId);

        assertEq(position.wbtcDebtAmount, debtPaidBack);

        uint256 delta = (debtPaidBack + position.claimableAmount) * 200 / 10_000; // 2% delta
        assertAlmostEq(
            debtPaidBack + position.claimableAmount,
            positionValueInWBTC - liquidationFee * position.claimableAmount / 1e8,
            delta
        );

        delta = (feeCollectorBalanceAfter - feeCollectorBalanceBefore) * 1000 / 10_000; // 10% delta
        assertAlmostEq(
            feeCollectorBalanceAfter - feeCollectorBalanceBefore, liquidationFee * position.claimableAmount / 1e8, delta
        );
    }

    function testLiquidationOfUSDCBasedPosition() external {
        // Set liquidateion BufferLeveragedStrategy
        uint256 liquidationFee = 0.02e8;
        LeveragedStrategy.StrategyConfig memory strategyConfig = LeveragedStrategy.StrategyConfig({
            quota: 100e8,
            maximumMultiplier: 3e8,
            positionLifetime: 1000,
            liquidationBuffer: 1.1e8,
            liquidationFee: liquidationFee
        });
        leveragedStrategy.setStrategyConfig(FRAXBPALUSD_STRATEGY, strategyConfig);

        uint256 nftId = openUSDCBasedPosition(1e8, 3e8);

        uint256 feeCollectorBalanceBefore = ERC20(WBTC).balanceOf(address(feeCollector));
        uint256 debtPaidBack = liquidateUSDCPosition(nftId);
        uint256 feeCollectorBalanceAfter = ERC20(WBTC).balanceOf(address(feeCollector));

        uint256 positionValueInWBTC = leveragedStrategy.previewPositionValueInWBTC(nftId);
        LedgerEntry memory position = positionLedger.getPosition(nftId);

        assertEq(position.wbtcDebtAmount, debtPaidBack);

        uint256 delta = (debtPaidBack + position.claimableAmount) * 200 / 10_000; // 2% delta
        assertAlmostEq(
            debtPaidBack + position.claimableAmount,
            positionValueInWBTC - liquidationFee * position.claimableAmount / 1e8,
            delta
        );

        delta = (feeCollectorBalanceAfter - feeCollectorBalanceBefore) * 1000 / 10_000; // 10% delta
        assertAlmostEq(
            feeCollectorBalanceAfter - feeCollectorBalanceBefore, liquidationFee * position.claimableAmount / 1e8, delta
        );
    }
}
