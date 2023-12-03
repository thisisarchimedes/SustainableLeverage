// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { IERC721A } from "ERC721A/IERC721A.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract ClosePositionTest is BaseTest {
    using ErrorsLeverageEngine for *;

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
        deal(WBTC, address(allContracts.wbtcVault), 100e8);
    }

    function _openPosition() internal {
        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(allContracts.positionOpener), 10e8);

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );
        allContracts.positionOpener.openPosition(
            5e8, 15e8, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
    }

    function test_ShouldRevertWithNotOwner() external {
        _openPosition();
        address ownerOfNft = allContracts.positionToken.ownerOf(0);
        assertEq(ownerOfNft, address(this), "Should be owner");
        allContracts.positionToken.transferFrom(address(this), positionReceiver, 0);
        vm.expectRevert(ErrorsLeverageEngine.NotOwner.selector);
        allContracts.positionCloser.closePosition(0, 0, SwapAdapter.SwapRoute.UNISWAPV3, "", address(0));
    }

    function test_ShouldRevertWithNotEnoughTokensReceived() external {
        _openPosition();
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000
            })
        );
        vm.expectRevert(ErrorsLeverageEngine.NotEnoughTokensReceived.selector);
        allContracts.positionCloser.closePosition(0, 5e8, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0));
    }

    function test_ShouldRevertIfPositionAlreadyClosed() external {
        _openPosition();
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000
            })
        );
        allContracts.positionCloser.closePosition(0, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0));
        vm.expectRevert();
        allContracts.positionCloser.closePosition(0, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0));
    }

    function test_ShouldClosePosition() external {
        _openPosition();
        address ownerOfNft = allContracts.positionToken.ownerOf(0);
        assertEq(ownerOfNft, address(this), "Should be owner");
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000
            })
        );

        uint256 wbtcBalanceBeforeClose = wbtc.balanceOf(address(allContracts.wbtcVault));

        allContracts.positionCloser.closePosition(0, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0));
        uint256 wbtcBalanceAfterClose = wbtc.balanceOf(address(allContracts.wbtcVault));
        LedgerEntry memory position = allContracts.positionLedger.getPosition(0);
        assertEq(uint8(position.state), uint8(PositionState.CLOSED));
        assertEq(wbtcBalanceAfterClose - wbtcBalanceBeforeClose, position.wbtcDebtAmount);
    }
}
