// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import { PositionLedgerLib } from "../src/PositionLedgerLib.sol";
import { LeverageEngine } from "../src/LeverageEngine.sol";
import { PositionToken } from "../src/PositionToken.sol";
import "../src/LeverageDepositor.sol";
import { WBTCVault } from "src/WBTCVault.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract BaseTest {
    LeverageEngine internal leverageEngine;
    PositionToken internal positionToken;
    LeverageDepositor internal leverageDepositor;
    WBTCVault internal wbtcVaultMock;
    ProxyAdmin internal proxyAdmin;
    TransparentUpgradeableProxy internal proxy;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant ETHPLUSETH_STRATEGY = 0xf3E920f099B19Ce604d672F0e87AAce490558fCA;

    function _prepareContracts() internal {
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
    }
}
