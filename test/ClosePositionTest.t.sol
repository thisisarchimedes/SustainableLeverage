// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
import "./helpers/OracleTestHelper.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { IERC721A } from "ERC721A/IERC721A.sol";
/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract ClosePositionTest is BaseTest {
    /* solhint-disable  */
    address positionReceiver = makeAddr("receiver");

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 18_369_197 });
        initTestFramework();
        deal(WBTC, address(wbtcVault), 100e8);
    }

    function _openPosition() internal {
        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(leverageEngine), 10e8);

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );
        leverageEngine.openPosition(
            5e8, 15e8, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
    }

    function test_ShouldRevertWithNotOwner() external {
        _openPosition();
        address ownerOfNft = positionToken.ownerOf(0);
        assertEq(ownerOfNft, address(this), "Should be owner");
        positionToken.transferFrom(address(this), positionReceiver, 0);
        vm.expectRevert(LeverageEngine.NotOwner.selector);
        leverageEngine.closePosition(0, 0, SwapAdapter.SwapRoute.UNISWAPV3, "", address(0));
    }

    function test_ShouldRevertWithNotEnoughTokensReceived() external {
        _openPosition();
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000
            })
        );
        vm.expectRevert(LeverageEngine.NotEnoughTokensReceived.selector);
        leverageEngine.closePosition(0, 5e8, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0));
    }

    function test_ShouldRevertIfPositionAlreadyClosed() external {
        _openPosition();
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000
            })
        );
        leverageEngine.closePosition(0, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0));
        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        leverageEngine.closePosition(0, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0));
    }

    function test_ShouldClosePosition() external {
        _openPosition();
        address ownerOfNft = positionToken.ownerOf(0);
        assertEq(ownerOfNft, address(this), "Should be owner");
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000
            })
        );

        uint256 wbtcBalanceBeforeClose = wbtc.balanceOf(address(wbtcVault));

        leverageEngine.closePosition(0, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0));
        uint256 wbtcBalanceAfterClose = wbtc.balanceOf(address(wbtcVault));
        PositionLedgerLib.LedgerEntry memory position = leverageEngine.getPosition(0);
        assertEq(uint8(position.state), uint8(PositionLedgerLib.PositionState.CLOSED));
        assertEq(wbtcBalanceAfterClose - wbtcBalanceBeforeClose, position.wbtcDebtAmount);
    }
}
