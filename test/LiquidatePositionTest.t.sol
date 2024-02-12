// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import { IAccessControl } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

// solhint-disable-next-line no-global-import
import "test/BaseTest.sol";

import { FakeOracle } from "src/ports/oracles/FakeOracle.sol";

import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";


contract LiquidatePositionTest is BaseTest {
    /* solhint-disable  */

    using ErrorsLeverageEngine for *;
    using ProtocolRoles for *;


    function setUp() public virtual {

        initFork();
        initTestFramework();

        deal(WBTC, address(allContracts.wbtcVault), 10_000_000e8);
        deal(WBTC, address(this), 10_000_000e8);
        ERC20(WBTC).approve(address(allContracts.positionOpener), type(uint256).max);
        ERC20(WBTC).approve(address(allContracts.positionCloser), type(uint256).max);
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
        allContracts.leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        assertEq(newLiquidationBuffer, allContracts.leveragedStrategy.getLiquidationBuffer(ETHPLUSETH_STRATEGY));

        newLiquidationBuffer = 1.15 * 10 ** 8; // 15%
        strategyConfig.liquidationBuffer = newLiquidationBuffer;
        allContracts.leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        assertEq(newLiquidationBuffer, allContracts.leveragedStrategy.getLiquidationBuffer(ETHPLUSETH_STRATEGY));
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
        allContracts.leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        assertEq(newLiquidationFee, allContracts.leveragedStrategy.getLiquidationFee(ETHPLUSETH_STRATEGY));

        newLiquidationFee = 0.05e8; // 5%
        strategyConfig.liquidationFee = newLiquidationFee;
        allContracts.leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        assertEq(newLiquidationFee, allContracts.leveragedStrategy.getLiquidationFee(ETHPLUSETH_STRATEGY));
    }

    function testWBTCPositionValueForUSDCPosition() external {
        uint256 collateralAmount = 5e8;
        uint256 borrowAmount = 15e8;

        uint256 nftId = openUSDCBasedPosition(collateralAmount, borrowAmount);

        uint256 positionValueInWBTC = allContracts.leveragedStrategy.previewPositionValueInWBTC(nftId);
        uint256 delta = (collateralAmount + borrowAmount) * 200 / 10_000; // 2% delta
        assertAlmostEq(collateralAmount + borrowAmount, positionValueInWBTC, delta);
    }

    function testWBTCPositionValueForWETHPosition() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);

        uint256 positionValueInWBTC = allContracts.leveragedStrategy.previewPositionValueInWBTC(nftId);
        uint256 delta = (collateralAmount + borrowAmount) * 200 / 10_000; // 2% delta
        assertAlmostEq(collateralAmount + borrowAmount, positionValueInWBTC, delta);
    }

    function testIsPositionNotLiquidatable() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);

        assertEq(allContracts.leveragedStrategy.isPositionLiquidatableEstimation(nftId), false);
    }

    function testIsPositionLiquidatable() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);

        assertEq(allContracts.leveragedStrategy.isPositionLiquidatableEstimation(nftId), false);

        FakeOracle fakeETHUSDOracle = new FakeOracle();
        fakeETHUSDOracle.updateFakePrice(100e8);
        fakeETHUSDOracle.updateDecimals(8);
        allContracts.oracleManager.setUSDOracle(WETH, fakeETHUSDOracle);

        assertEq(allContracts.leveragedStrategy.isPositionLiquidatableEstimation(nftId), true);
    }

    function testIsPositionLiquidatableRevertsOnClosedPosition() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);

        closeETHBasedPosition(nftId);

        vm.expectRevert(ErrorsLeverageEngine.PositionNotLive.selector);
        allContracts.leveragedStrategy.isPositionLiquidatableEstimation(nftId);
    }

    function testIsPositionLiquidatableRevertsOnNonExistingNFT() external {
        vm.expectRevert(ErrorsLeverageEngine.PositionNotLive.selector);
        allContracts.leveragedStrategy.isPositionLiquidatableEstimation(999_999);
    }

    function testLiquditionRevertsIfPositionIsClosed() external {
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);

        closeETHBasedPosition(nftId);

        allContracts.positionLiquidator.setMonitor(address(this));

        bytes memory payloadClose = getWETHWBTCUniswapPayload();

        ClosePositionParams memory params = ClosePositionParams({
            nftId: nftId,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payloadClose,
            exchange: address(0)
        });
        
        vm.expectRevert(bytes("ERC4626: redeem more than max"));
        allContracts.positionLiquidator.liquidatePosition(params);
    }

    function testLiquidationOfETHBasedPosition() external {
        uint256 liquidationFee = 0.02e8;
        LeveragedStrategy.StrategyConfig memory strategyConfig = LeveragedStrategy.StrategyConfig({
            quota: 100e8,
            maximumMultiplier: 3e8,
            positionLifetime: 1000,
            liquidationBuffer: 1.1e8,
            liquidationFee: liquidationFee
        });
        allContracts.leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);

        uint256 nftId = openETHBasedPosition(10e8, 30e8);

        uint256 feeCollectorBalanceBefore = ERC20(WBTC).balanceOf(address(feeCollector));
        uint256 debtPaidBack = liquidateETHPosition(nftId);
        uint256 feeCollectorBalanceAfter = ERC20(WBTC).balanceOf(address(feeCollector));

        uint256 positionValueInWBTC = allContracts.leveragedStrategy.previewPositionValueInWBTC(nftId);
        LedgerEntry memory position = allContracts.positionLedger.getPosition(nftId);

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

        if (allContracts.positionLedger.getPositionState(nftId) != PositionState.LIQUIDATED) {
            assertEq(true, false);
        }
    }

    function testLiquidationOfUSDCBasedPosition() external {

        uint256 liquidationFee = 0.02e8;
        LeveragedStrategy.StrategyConfig memory strategyConfig = LeveragedStrategy.StrategyConfig({
            quota: 100e8,
            maximumMultiplier: 3e8,
            positionLifetime: 1000,
            liquidationBuffer: 1.1e8,
            liquidationFee: liquidationFee
        });
        allContracts.leveragedStrategy.setStrategyConfig(FRAXBPALUSD_STRATEGY, strategyConfig);

        uint256 nftId = openUSDCBasedPosition(1e8, 3e8);

        uint256 feeCollectorBalanceBefore = ERC20(WBTC).balanceOf(address(feeCollector));
        uint256 debtPaidBack = liquidateUSDCPosition(nftId);
        uint256 feeCollectorBalanceAfter = ERC20(WBTC).balanceOf(address(feeCollector));

        uint256 positionValueInWBTC = allContracts.leveragedStrategy.previewPositionValueInWBTC(nftId);
        LedgerEntry memory position = allContracts.positionLedger.getPosition(nftId);

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

        if (allContracts.positionLedger.getPositionState(nftId) != PositionState.LIQUIDATED) {
            assertEq(true, false);
        }
    }

    function testSendLeftoverToExpirationVault() external {
        
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;
        uint256 expirationVaultBalance = ERC20(WBTC).balanceOf(address(allContracts.expiredVault));

        uint256 liquidationFee = 0.02e8;
        LeveragedStrategy.StrategyConfig memory strategyConfig = LeveragedStrategy.StrategyConfig({
            quota: 100e8,
            maximumMultiplier: 3e8,
            positionLifetime: 1000,
            liquidationBuffer: 1.1e8,
            liquidationFee: liquidationFee
        });
        allContracts.leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);
        uint256 debtPaidBack = liquidateETHPosition(nftId);

        expirationVaultBalance = ERC20(WBTC).balanceOf(address(allContracts.expiredVault)) - expirationVaultBalance;

        assertGt(expirationVaultBalance, 0);
        assertLte(expirationVaultBalance, collateralAmount + borrowAmount - debtPaidBack);
    }

    function testAllDebtGotBackToValue() external {
        
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;
        uint256 wbtcVaultBalanceBefore = ERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
        assertGt(wbtcVaultBalanceBefore, 0);

        uint256 liquidationFee = 0.02e8;
        LeveragedStrategy.StrategyConfig memory strategyConfig = LeveragedStrategy.StrategyConfig({
            quota: 100e8,
            maximumMultiplier: 3e8,
            positionLifetime: 1000,
            liquidationBuffer: 1.1e8,
            liquidationFee: liquidationFee
        });
        allContracts.leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);
        uint256 debtPaidBack = liquidateETHPosition(nftId);

        uint256 wbtcVaultBalanceAfter = ERC20(WBTC).balanceOf(address(allContracts.wbtcVault));

        assertEq(debtPaidBack, borrowAmount);
        assertEq(wbtcVaultBalanceBefore, wbtcVaultBalanceAfter);
    }

    function testNonMonitorCannotLiquidate() external {
        
        uint256 collateralAmount = 10e8;
        uint256 borrowAmount = 30e8;

        uint256 liquidationFee = 0.02e8;
        LeveragedStrategy.StrategyConfig memory strategyConfig = LeveragedStrategy.StrategyConfig({
            quota: 100e8,
            maximumMultiplier: 3e8,
            positionLifetime: 1000,
            liquidationBuffer: 1.1e8,
            liquidationFee: liquidationFee
        });
        allContracts.leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);

        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);
        
        ClosePositionParams memory params = ClosePositionParams({
            nftId: nftId,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: getWBTCWETHUniswapPayload(),
            exchange: address(0)
        });

        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, 0, ProtocolRoles.MONITOR_ROLE));
        allContracts.positionLiquidator.liquidatePosition(params);
    }
}
