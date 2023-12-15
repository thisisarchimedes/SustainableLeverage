// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import { IAccessControl } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "test/BaseTest.sol";

import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";

import { FakeWBTCWETHSwapAdapter } from "src/ports/swap_adapters/FakeWBTCWETHSwapAdapter.sol";
import { FakeOracle } from "src/ports/oracles/FakeOracle.sol";

import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";


contract NoFlashLoanTest is BaseTest {
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

    function testCantOpenAndClosePositionAtTheSameBlock() external {

        uint8 minBlockDuration = 50;
        allContracts.protocolParameters.setMinPositionDurationInBlocks(minBlockDuration);

        uint256 collateralAmount = 5e8;
        uint256 borrowAmount = 15e8;

        uint256 currentBlockNumber = block.number;
        uint256 nftId = openUSDCBasedPosition(collateralAmount, borrowAmount);
        assertEq(block.number, currentBlockNumber);

        ClosePositionParams memory params = ClosePositionParams({
            nftId: nftId,
            minWBTC: 5e8,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: getUSDCWBTCUniswapPayload(),
            exchange: address(0)
        });

        vm.expectRevert(ErrorsLeverageEngine.PositionMustLiveForMinDuration.selector);
        allContracts.positionCloser.closePosition(params);
        
        assertEq(block.number, currentBlockNumber);
    }

    function testNotAllowedToClosePositionBeforeMinBlockDuration() external {

        uint8 minBlockDuration = 50;
        allContracts.protocolParameters.setMinPositionDurationInBlocks(minBlockDuration);

        uint256 collateralAmount = 5e8;
        uint256 borrowAmount = 15e8;

        uint256 currentBlockNumber = block.number;
        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);
        assertEq(block.number, currentBlockNumber);

        vm.roll(block.number + minBlockDuration - 1);

        ClosePositionParams memory params = ClosePositionParams({
            nftId: nftId,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: getWETHWBTCUniswapPayload(),
            exchange: address(0)
        });

        vm.expectRevert(ErrorsLeverageEngine.PositionMustLiveForMinDuration.selector);
        allContracts.positionCloser.closePosition(params);

        if (allContracts.positionLedger.getPositionState(nftId) == PositionState.CLOSED) {
            assertEq(true, false);
        }
    }

    function testCanClosePositionAfterMinBlockDuration() external {

        uint8 minBlockDuration = 50;
        allContracts.protocolParameters.setMinPositionDurationInBlocks(minBlockDuration);

        uint256 collateralAmount = 5e8;
        uint256 borrowAmount = 15e8;

        uint256 currentBlockNumber = block.number;
        uint256 nftId = openETHBasedPosition(collateralAmount, borrowAmount);
        assertEq(block.number, currentBlockNumber);

        ClosePositionParams memory params = ClosePositionParams({
            nftId: nftId,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: getWETHWBTCUniswapPayload(),
            exchange: address(0)
        });

        vm.roll(block.number + minBlockDuration + 1);
        allContracts.positionCloser.closePosition(params);

        if (allContracts.positionLedger.getPositionState(nftId) != PositionState.CLOSED) {
            assertEq(true, false);
        }
    }
}

