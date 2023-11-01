// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { PositionLedgerLib } from "../src/PositionLedgerLib.sol";
import { LeverageEngine } from "../src/LeverageEngine.sol";
import { PositionToken } from "../src/PositionToken.sol";
import "../src/LeverageDepositor.sol";
import { WBTCVault } from "src/WBTCVault.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { SwapAdapter } from "../src/SwapAdapter.sol";
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";

contract DeployContracts is Script {
    /* solhint-disable  */
    LeverageEngine internal leverageEngine;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant ETHPLUSETH_STRATEGY = 0xf3E920f099B19Ce604d672F0e87AAce490558fCA;
    address public constant WBTCUSDORACLE = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public constant ETHUSDORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDCUSDORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant FRAXBPALUSD_STRATEGY = 0xB888b8204Df31B54728e963ebA5465A95b695103;

    function run() public {
        address broadcaster = vm.rememberKey(0xb7f3cdcc39c740a28a063f57af7583d3bea1b4473772f4a43721777680475740); // THIS
            // IS DUMMY KEY
        vm.startBroadcast(broadcaster);
        leverageEngine = LeverageEngine(0x031B101080777417811752b5Aa059Fc188e58F2F); // UPDATE THIS WITH LATEST ADDRESS

        ERC20(WBTC).approve(address(leverageEngine), 1e8);
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(500), WETH, uint24(3000), USDC),
                deadline: block.timestamp + 1000
            })
        );
        leverageEngine.openPosition(
            0.1e8, 0.1e8, FRAXBPALUSD_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );

        if (block.chainid == 1337) {
            bytes32 storageSlot = keccak256(abi.encode(address(broadcaster), 0));
            uint256 amount = 1000e8;
            string[] memory inputs = new string[](5);
            inputs[0] = "python3";
            inputs[1] = "script/setupFork.py";
            inputs[2] = vm.toString(storageSlot);
            inputs[3] = vm.toString(WBTC);
            inputs[4] = vm.toString(bytes32(amount));

            vm.ffi(inputs);
        }
        vm.stopBroadcast();
    }
}
