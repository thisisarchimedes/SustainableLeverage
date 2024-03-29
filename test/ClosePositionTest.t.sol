// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

// solhint-disable-next-line no-global-import
import "test/BaseTest.sol";

import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";

contract ClosePositionTest is BaseTest {
    using ErrorsLeverageEngine for *;

    address private positionReceiver = makeAddr("receiver");

    function setUp() public virtual {
        initFork();
        initTestFramework();

        deal(WBTC, address(allContracts.wbtcVault), 100e8);
    }

    function test_ShouldRevertWithNotOwner() external {
        openETHBasedPosition(5e8, 15e8);

        address ownerOfNft = allContracts.positionToken.ownerOf(0);
        assertEq(ownerOfNft, address(this), "Should be owner");

        allContracts.positionToken.transferFrom(address(this), positionReceiver, 0);

        ClosePositionParams memory params = ClosePositionParams({
            nftId: 0,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: "",
            exchange: address(0)
        });

        vm.roll(block.number + TWO_DAYS);
        vm.expectRevert(ErrorsLeverageEngine.NotOwner.selector);
        allContracts.positionCloser.closePosition(params);
    }

    function test_ShouldRevertWithNotEnoughTokensReceived() external {
        openETHBasedPosition(5e8, 15e8);

        bytes memory payload = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000,
                amountOutMin: 1
            })
        );

        ClosePositionParams memory params = ClosePositionParams({
            nftId: 0,
            minWBTC: 5e8,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });

        vm.roll(block.number + TWO_DAYS);
        vm.expectRevert(ErrorsLeverageEngine.NotEnoughTokensReceived.selector);
        allContracts.positionCloser.closePosition(params);
    }

    function test_ShouldRevertIfPositionAlreadyClosed() external {
        openETHBasedPosition(5e8, 15e8);

        bytes memory payload = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000,
                amountOutMin: 1
            })
        );

        ClosePositionParams memory params = ClosePositionParams({
            nftId: 0,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });

        vm.roll(block.number + TWO_DAYS);
        allContracts.positionCloser.closePosition(params);
        vm.expectRevert();
        allContracts.positionCloser.closePosition(params);
    }

    function test_shouldRevertIfNotMinTimePassed() external {
        openETHBasedPosition(5e8, 15e8);
        bytes memory payload = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000,
                amountOutMin: 1
            })
        );

        ClosePositionParams memory params = ClosePositionParams({
            nftId: 0,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });

        vm.expectRevert(ErrorsLeverageEngine.PositionMustLiveForMinDuration.selector);
        allContracts.positionCloser.closePosition(params);
    }

    function test_ShouldClosePosition() external {
        openETHBasedPosition(5e8, 15e8);

        address ownerOfNft = allContracts.positionToken.ownerOf(0);
        assertEq(ownerOfNft, address(this), "Should be owner");
        bytes memory payload = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000,
                amountOutMin: 1
            })
        );

        uint256 wbtcBalanceBeforeClose = wbtc.balanceOf(address(allContracts.wbtcVault));

        vm.roll(block.number + TWO_DAYS);

        ClosePositionParams memory params = ClosePositionParams({
            nftId: 0,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });
        allContracts.positionCloser.closePosition(params);

        uint256 wbtcBalanceAfterClose = wbtc.balanceOf(address(allContracts.wbtcVault));
        LedgerEntry memory position = allContracts.positionLedger.getPosition(0);
        assertEq(uint8(position.state), uint8(PositionState.CLOSED));
        assertEq(wbtcBalanceAfterClose - wbtcBalanceBeforeClose, position.wbtcDebtAmount);
    }

    function testDepositWhenStrategyAssetInWbtcAndClose() external {
        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(allContracts.positionOpener), type(uint256).max);

        IMultiPoolStrategy strategy = IMultiPoolStrategy(UNIV3_WBTC_WETH_STRATEGY_LEVERAGE);

        bytes memory payload = "";
        OpenPositionParams memory params = OpenPositionParams({
            collateralAmount: 10e8,
            wbtcToBorrow: 20e8,
            minStrategyShares: 0,
            strategy: UNIV3_WBTC_WETH_STRATEGY_LEVERAGE,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });
        uint256 nftId = allContracts.positionOpener.openPosition(params);
        vm.roll(block.number + TWO_DAYS);
        ClosePositionParams memory closeParams = ClosePositionParams({
            nftId: nftId,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });
        uint256 wbtcBalanceBefore = ERC20(WBTC).balanceOf(address(this));
        allContracts.positionCloser.closePosition(closeParams);
        uint256 wbtcBalanceAfter = ERC20(WBTC).balanceOf(address(this));
        uint256 delta = 10e8 * 2e8 / 100e8;
        assertAlmostEq(wbtcBalanceAfter - wbtcBalanceBefore, 10e8, delta);
    }
}
