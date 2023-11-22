// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { BaseScript } from "./Base.s.sol";
import { PositionLedgerLib } from "../src/PositionLedgerLib.sol";
import  "../src/LeverageEngine.sol";
import { PositionToken } from "../src/PositionToken.sol";
import "../src/LeverageDepositor.sol";
import { WBTCVault } from "src/WBTCVault.sol";
import { ILeverageEngine } from "src/interfaces/ILeverageEngine.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { SwapAdapter } from "../src/SwapAdapter.sol";
import { ChainlinkOracle } from "../src/ports/ChainlinkOracle.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployContracts is BaseScript {
    LeverageEngine internal leverageEngine;
    PositionToken internal positionToken;
    LeverageDepositor internal leverageDepositor;
    WBTCVault internal wbtcVault;
    ProxyAdmin internal proxyAdmin;
    TransparentUpgradeableProxy internal proxy;
    SwapAdapter internal swapAdapter;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant ETHPLUSETH_STRATEGY = 0xf3E920f099B19Ce604d672F0e87AAce490558fCA;
    address public constant WBTCUSDORACLE = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public constant ETHUSDORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDCUSDORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant FRAXBPALUSD_STRATEGY = 0xB888b8204Df31B54728e963ebA5465A95b695103;

    function run() public broadcast {
        proxyAdmin = new ProxyAdmin(address(this));
        deployedContracts.push(address(proxyAdmin));
        deployedContractsNames.push("ProxyAdmin");
        positionToken = new PositionToken();
        deployedContracts.push(address(positionToken));
        deployedContractsNames.push("PositionToken");
        leverageDepositor = new LeverageDepositor(WBTC,WETH);
        deployedContracts.push(address(leverageDepositor));
        deployedContractsNames.push("LeverageDepositor");
        wbtcVault = new WBTCVault(WBTC);
        deployedContracts.push(address(wbtcVault));
        deployedContractsNames.push("WBTCVault");
        leverageEngine = new LeverageEngine();
        deployedContracts.push(address(leverageEngine));
        deployedContractsNames.push("LeverageEngineImplementation");
        swapAdapter = new SwapAdapter(WBTC, address(leverageDepositor));
        deployedContracts.push(address(swapAdapter));
        deployedContractsNames.push("SwapAdapter");
        bytes memory initData = abi.encodeWithSelector(
            LeverageEngine.initialize.selector,
            address(wbtcVault),
            address(leverageDepositor),
            address(positionToken),
            address(swapAdapter),
            broadcaster
        );
        proxy = new TransparentUpgradeableProxy(address(leverageEngine), address(proxyAdmin), initData);
        deployedContracts.push(address(proxy));
        deployedContractsNames.push("LeverageEngine");
        leverageEngine = LeverageEngine(address(proxy));
        leverageEngine.setOracle(WBTC, new ChainlinkOracle(WBTCUSDORACLE));
        leverageEngine.setOracle(WETH, new ChainlinkOracle(ETHUSDORACLE));
        leverageEngine.setOracle(USDC, new ChainlinkOracle(USDCUSDORACLE));
        _writeDeploymentsToJson();
        if (block.chainid == 1337) {
            LeverageEngine.StrategyConfig memory strategyConfig = ILeverageEngine.StrategyConfig({
                quota: 10_000e8,
                maximumMultiplier: 3e8,
                positionLifetime: 1000,
                liquidationBuffer: 1.25e8,
                liquidationFee: 0.02e8
            });

            leverageEngine.setStrategyConfig(FRAXBPALUSD_STRATEGY, strategyConfig);
            bytes32 storageSlot = keccak256(abi.encode(address(wbtcVault), 0));
            uint256 amount = 1_000_000e8;
            string[] memory inputs = new string[](5);
            inputs[0] = "python";
            inputs[1] = "script/setupFork.py";
            inputs[2] = vm.toString(storageSlot);
            inputs[3] = vm.toString(WBTC);
            inputs[4] = vm.toString(bytes32(amount));

            vm.ffi(inputs);
        }
    }
}
