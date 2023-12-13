// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { PositionOpener } from "src/PositionOpener.sol";
import { LeveragedStrategy } from "src/LeveragedStrategy.sol";
import { PositionToken } from "src/PositionToken.sol";
import "src/LeverageDepositor.sol";
import { WBTCVault } from "src/WBTCVault.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { SwapManager } from "src/SwapManager.sol";
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { UniV3SwapAdapter } from "src/ports/swap_adapters/UniV3SwapAdapter.sol";

contract OpenPosition is Script {
    /* solhint-disable  */
    PositionOpener internal positionOpener;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WBTCUSDORACLE = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public constant ETHUSDORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDCUSDORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant ETHPLUSETH_STRATEGY = 0xF326Cd46A1A189B305AFF7500b02C5C26b405266;
    address public constant FRAXBPALUSD_STRATEGY = 0xD078a331A8A00AB5391ba9f3AfC910225a78e6A1;

    function run() public {
        address broadcaster = vm.rememberKey(0xfb3e889306aafa69793a67e74c09e657eec07c4c552543db26f3158cf53c2a57); // THIS
            // IS DUMMY KEY
        vm.startBroadcast(broadcaster);
        positionOpener = PositionOpener(0x4009141515614E2E7025aB2fDb840DD39B22C4a1); // UPDATE THIS WITH LATEST ADDRESS

        ERC20(WBTC).approve(address(positionOpener), type(uint256).max);

        bytes memory payload = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), USDC),
                deadline: block.timestamp + 1000
            })
        );

        PositionOpener.OpenPositionParams memory params = PositionOpener.OpenPositionParams({
            collateralAmount: 0.1e8,
            wbtcToBorrow: 0.1e8,
            minStrategyShares: 0,
            strategy: FRAXBPALUSD_STRATEGY,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });

        positionOpener.openPosition(params);

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
