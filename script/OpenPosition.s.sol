//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { PositionOpener } from "src/user_facing/PositionOpener.sol";
import { PositionToken } from "src/user_facing/PositionToken.sol";

import { LeveragedStrategy } from "src/internal/LeveragedStrategy.sol";
import { WBTCVault } from "src/internal/WBTCVault.sol";
import { SwapManager } from "src/internal/SwapManager.sol";
import { IMultiPoolStrategy } from "src/interfaces/IMultiPoolStrategy.sol";

import { UniV3SwapAdapter } from "src/ports/swap_adapters/UniV3SwapAdapter.sol";
import { OpenPositionParams } from "src/libs/PositionCallParams.sol";

contract OpenPosition is Script {
    /* solhint-disable  */
    PositionOpener internal positionOpener = PositionOpener(0x404e1256Ad4Dfd361eb682D60cb24757Ce77740B); // UPDATE THIS
        // WITH LATEST ADDRESS

    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WBTCUSDORACLE = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public constant ETHUSDORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDCUSDORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant ETHPLUSETH_STRATEGY = 0xF326Cd46A1A189B305AFF7500b02C5C26b405266;
    address public constant FRAXBPALUSD_STRATEGY = 0xD078a331A8A00AB5391ba9f3AfC910225a78e6A1;
    address public constant UNIV3_STRATEGY = 0x7694Cd972Baa64018e5c6389740832e4C7f2Ce9a;

    function run() public {
        address OPEN_POSITION_STRATEGY = UNIV3_STRATEGY;

        address broadcaster = vm.rememberKey(0xfb3e889306aafa69793a67e74c09e657eec07c4c552543db26f3158cf53c2a57); // THIS
            // IS DUMMY KEY
        vm.startBroadcast(broadcaster);
        console2.log("Broadcaster address:", broadcaster); // Print the broadcaster address

        console2.log("WBTC Vault balance:", ERC20(WBTC).balanceOf(0xF33BC53141054024cf585e14fC7c824c48Fb8B9e));
        console2.log("Broadcaster balance:", ERC20(WBTC).balanceOf(broadcaster));

        //! adjustIn check
        // console2.log(IMultiPoolStrategy(OPEN_POSITION_STRATEGY).storedTotalAssets());
        // console2.log(IMultiPoolStrategy(OPEN_POSITION_STRATEGY).adjustInInterval());
        // return;

        ERC20(WBTC).approve(address(positionOpener), type(uint256).max);

        // bytes memory payload = abi.encode(
        //     UniV3SwapAdapter.UniswapV3Data({
        //         path: abi.encodePacked(WBTC, uint24(3000), USDC),
        //         deadline: block.timestamp + 30 days,
        //         amountOutMin: 1
        //     })
        // );
        bytes memory payload; // For UNIV3_STRATEGY

        OpenPositionParams memory params = OpenPositionParams({
            collateralAmount: 0.1e8,
            wbtcToBorrow: 0.1e8,
            minStrategyShares: 0,
            strategy: OPEN_POSITION_STRATEGY,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });

        positionOpener.openPosition(params);

        vm.stopBroadcast();
    }
}
