// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { PositionLiquidator } from "src/monitor_facing/PositionLiquidator.sol";
import { ExpiredVault } from "src/user_facing/ExpiredVault.sol";
import { SwapManager } from "src/internal/SwapManager.sol";
import { ClosePositionParams } from "src/libs/PositionCallParams.sol";

import { UniV3SwapAdapter } from "src/ports/swap_adapters/UniV3SwapAdapter.sol";

contract LiquidatePosition is Script {
    PositionLiquidator positionLiquidator = PositionLiquidator(0xfB3579fCE33D7733D5Ca7D023D4164627F4caFd1); // UPDATE
        // THIS WITH LATEST ADDRESS
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

        // Liquidate position
        uint256 nftId = 0;
        bytes memory payloadClose = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(USDC, uint24(3000), WETH, uint24(500), WBTC),
                deadline: block.timestamp + 30 days,
                amountOutMin: 1
            })
        );
        ClosePositionParams memory closeParams = ClosePositionParams({
            nftId: nftId,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payloadClose,
            exchange: address(0)
        });
        console2.log(block.number, block.timestamp);
        positionLiquidator.liquidatePosition(closeParams);
    }
}
