// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProtocolParameters } from "src/internal/ProtocolParameters.sol";
import { PositionCloser } from "src/user_facing/PositionCloser.sol";
import { PositionExpirator } from "src/monitor_facing/PositionExpirator.sol";
import { ClosePositionParams } from "src/libs/PositionCallParams.sol";
import { UniV3SwapAdapter } from "src/ports/swap_adapters/UniV3SwapAdapter.sol";
import { SwapManager } from "src/internal/SwapManager.sol";
import { Script } from "forge-std/Script.sol";
import { Constants } from "src/libs/Constants.sol";

contract ExpirePosition is Script {
    /* solhint-disable  */
    PositionExpirator internal positionExpirator;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant ETHPLUSETH_STRATEGY = 0xf3E920f099B19Ce604d672F0e87AAce490558fCA;
    address public constant WBTCUSDORACLE = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public constant ETHUSDORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDCUSDORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant FRAXBPALUSD_STRATEGY = 0xB888b8204Df31B54728e963ebA5465A95b695103;

    function bytesToString(bytes memory data) public pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    function run() public {
        address broadcaster = vm.rememberKey(0xfb3e889306aafa69793a67e74c09e657eec07c4c552543db26f3158cf53c2a57); // THIS
        // IS DUMMY KEY
        vm.startBroadcast(broadcaster);
        positionExpirator = PositionExpirator(0x6eA0b907F6D72fA1b2851b6aa4AA2b3D46ECeD1e); // UPDATE THIS WITH LATEST
            // ADDRESS

        bytes memory path = abi.encodePacked(USDC, uint24(500), WBTC);

        console2.log("path", bytesToString(path));

        bytes memory payloadI = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: path,
                // deadline: block.timestamp + 100_000_000_000_000,
                deadline: 1_808_412_831,
                amountOutMin: 1
            })
        );

        string memory payloadS =
            "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000006bca309f0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001f42260fac5e5542a773aa44fbcfedf7c193bc2c599000000000000000000000000000000000000000000";

        console2.log("payloadI", bytesToString(payloadI));
        console2.log("payloadS", payloadS);
        // console2.log("payload", bytesToString(payload));

        ClosePositionParams memory params = ClosePositionParams({
            nftId: 5,
            minWBTC: 1,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payloadI,
            exchange: address(0)
        });

        positionExpirator.expirePosition(5, params);

        vm.stopBroadcast();
    }
}
