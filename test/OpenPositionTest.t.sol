// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { PositionLedgerLib } from "../src/PositionLedgerLib.sol";
import { LeverageEngine } from "../src/LeverageEngine.sol";
import { PositionToken } from "../src/PositionToken.sol";
import "../src/LeverageDepositor.sol";
import { WBTCVault } from "src/WBTCVault.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract OpenPositionTest is PRBTest, StdCheats {
    LeverageEngine internal leverageEngine;
    PositionToken internal positionToken;
    LeverageDepositor internal leverageDepositor;
    WBTCVault internal wbtcVaultMock;
    ProxyAdmin internal proxyAdmin;
    TransparentUpgradeableProxy internal proxy;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant ETHPLUSETH_STRATEGY = 0xf3E920f099B19Ce604d672F0e87AAce490558fCA;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 18_369_197 });
        proxyAdmin = new ProxyAdmin(address(this));
        positionToken = new PositionToken();
        leverageDepositor = new LeverageDepositor(WBTC,WETH);
        wbtcVaultMock = new WBTCVault(WBTC);
        leverageEngine = new LeverageEngine();
        bytes memory initData = abi.encodeWithSelector(
            LeverageEngine.initialize.selector,
            address(wbtcVaultMock),
            address(leverageDepositor),
            address(positionToken)
        );
        proxy = new TransparentUpgradeableProxy(address(leverageEngine), address(proxyAdmin), initData);
        leverageEngine = LeverageEngine(address(proxy));
        deal(WBTC, address(wbtcVaultMock), 100e8);
        deal(WETH, address(leverageDepositor), 1000e18);
    }

    function test_ShouldRevertWithArithmeticOverflow() external {
        vm.expectRevert();
        leverageEngine.openPosition(
            5e18, 5e18, ETHPLUSETH_STRATEGY, 0, ILeverageDepositor.SwapRoute.WBTCWETH_CURVE_TRIPOOL
        );
    }

    function test_ShouldRevertWithExceedBorrowLimit() external {
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, 100e8, 1000, 3e8, 1.25e8);
        vm.expectRevert(LeverageEngine.ExceedBorrowLimit.selector);
        leverageEngine.openPosition(
            5e8, 80e8, ETHPLUSETH_STRATEGY, 0, ILeverageDepositor.SwapRoute.WBTCWETH_CURVE_TRIPOOL
        );
    }

    function test_ShouldAbleToOpenPos() external {
        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(leverageEngine), 10e8);
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, 100e8, 1000, 3e8, 1.25e8);
        leverageEngine.openPosition(
            5e8, 15e8, ETHPLUSETH_STRATEGY, 0, ILeverageDepositor.SwapRoute.WBTCWETH_CURVE_TRIPOOL
        );
        PositionLedgerLib.LedgerEntry memory position = leverageEngine.getPosition(0);
        assertEq(position.collateralAmount, 5e8);
        assertEq(position.wbtcDebtAmount, 15e8);
    }
    //erc721 receiver

    function onERC721Received(address, address, uint256, bytes memory) public returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
