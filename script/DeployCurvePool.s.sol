    // SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProtocolParameters } from "src/internal/ProtocolParameters.sol";
import { PositionCloser } from "src/user_facing/PositionCloser.sol";
import { ClosePositionParams } from "src/libs/PositionCallParams.sol";
import { UniV3SwapAdapter } from "src/ports/swap_adapters/UniV3SwapAdapter.sol";
import { SwapManager } from "src/internal/SwapManager.sol";
import { console2 } from "forge-std/console2.sol";
import { BaseScript } from "script/Base.s.sol";
import { Constants } from "src/libs/Constants.sol";
import { ICurvePool } from "../src/interfaces/ICurvePool.sol";
import { ICurveStableswapFactoryNG } from "src/interfaces/ICurveStableswapFactoryNG.sol";

contract DeployContracts is BaseScript {
    address public constant CURVE_STABLE_FACTORY_NG_ADDRESS = 0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    function run() public broadcast {
        string memory name = "LVBTC-WBTC-Arch-Test";
        string memory symbol = "LWAT";
        uint256 A = 4000;
        uint256 fee = 4_000_000; // 0.3%
        uint256 offpeg_fee_multiplier = 20_000_000_000;
        uint256 ma_exp_time = 866; // 1 day
        uint256 implementation_idx = 0;
        uint8[] memory asset_types = new uint8[](2);
        asset_types[0] = 0;
        bytes4[] memory method_ids = new bytes4[](2);
        method_ids[0] = 0;
        method_ids[1] = 0;
        address[] memory oracles = new address[](2);

        ICurvePool deployedPool = initdeployCurvePool(
            address(WBTC),
            name,
            symbol,
            A,
            fee,
            offpeg_fee_multiplier,
            ma_exp_time,
            implementation_idx,
            asset_types,
            method_ids,
            oracles
        );
    }

    function initdeployCurvePool(
        address _lvBTC,
        string memory name,
        string memory symbol,
        uint256 A,
        uint256 fee,
        uint256 offpeg_fee_multiplier,
        uint256 ma_exp_time,
        uint256 implementation_idx,
        uint8[] memory asset_types,
        bytes4[] memory method_ids,
        address[] memory oracles
    )
        internal
        returns (ICurvePool)
    {
        address[] memory coins = new address[](2);
        coins[0] = address(WBTC);
        coins[1] = address(_lvBTC);

        address poolAddress = ICurveStableswapFactoryNG(CURVE_STABLE_FACTORY_NG_ADDRESS).deploy_plain_pool(
            name,
            symbol,
            coins,
            A,
            fee,
            offpeg_fee_multiplier,
            ma_exp_time,
            implementation_idx,
            asset_types,
            method_ids,
            oracles
        );

        return ICurvePool(poolAddress);
    }
}
