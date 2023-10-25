// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import { PositionLedgerLib } from "../src/PositionLedgerLib.sol";
import "../src/LeverageEngine.sol";
import { PositionToken } from "../src/PositionToken.sol";
import "../src/LeverageDepositor.sol";
import { WBTCVault } from "src/WBTCVault.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { SwapAdapter } from "../src/SwapAdapter.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract BaseTest is PRBTest, StdCheats {
    address feeCollector = makeAddr("feeCollector");
    LeverageEngine internal leverageEngine;
    PositionToken internal positionToken;
    LeverageDepositor internal leverageDepositor;
    WBTCVault internal wbtcVault;
    ProxyAdmin internal proxyAdmin;
    TransparentUpgradeableProxy internal proxy;
    SwapAdapter internal swapAdapter;
    IERC20 internal wbtc;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant ETHPLUSETH_STRATEGY = 0xf3E920f099B19Ce604d672F0e87AAce490558fCA;
    address public constant WBTCUSDORACLE = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public constant ETHUSDORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDCUSDORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant FRAXBPALUSD_STRATEGY = 0xB888b8204Df31B54728e963ebA5465A95b695103;

    function _prepareContracts() internal {
        proxyAdmin = new ProxyAdmin(address(this));
        positionToken = new PositionToken();
        leverageDepositor = new LeverageDepositor(WBTC,WETH);
        wbtcVault = new WBTCVault(WBTC);
        leverageEngine = new LeverageEngine();
        swapAdapter = new SwapAdapter(WBTC, address(leverageDepositor));
        bytes memory initData = abi.encodeWithSelector(
            LeverageEngine.initialize.selector,
            address(wbtcVault),
            address(leverageDepositor),
            address(positionToken),
            address(swapAdapter),
            address(feeCollector)
        );
        proxy = new TransparentUpgradeableProxy(address(leverageEngine), address(proxyAdmin), initData);
        leverageEngine = LeverageEngine(address(proxy));
        leverageEngine.setOracle(WBTC, WBTCUSDORACLE);
        leverageEngine.setOracle(WETH, ETHUSDORACLE);
        leverageEngine.setOracle(USDC, USDCUSDORACLE);
        wbtc = IERC20(WBTC);
    }
    //erc721 receiver

    function onERC721Received(address, address, uint256, bytes memory) public returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
