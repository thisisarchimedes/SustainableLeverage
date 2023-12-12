// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { PositionToken } from "src/PositionToken.sol";
import "../src/LeverageDepositor.sol";
import { WBTCVault } from "src/WBTCVault.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";
import { ExpiredVault } from "src/ExpiredVault.sol";
import { FakeOracle } from "src/ports/oracles/FakeOracle.sol";
import { FakeWBTCWETHSwapAdapter } from "src/ports/swap_adapters/FakeWBTCWETHSwapAdapter.sol";
import { FakeWBTCUSDCSwapAdapter } from "src/ports/swap_adapters/FakeWBTCUSDCSwapAdapter.sol";
import { ChainlinkOracle } from "src/ports/oracles/ChainlinkOracle.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { ExpiredVault } from "src/ExpiredVault.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ProtocolParameters } from "src/ProtocolParameters.sol";
import { PositionLedger, LedgerEntry, PositionState } from "src/PositionLedger.sol";
import { PositionOpener } from "src/PositionOpener.sol";
import { PositionCloser } from "src/PositionCloser.sol";
import { OracleManager } from "src/OracleManager.sol";
import { LeveragedStrategy } from "src/LeveragedStrategy.sol";
import { SwapManager } from "src/SwapManager.sol";
import { UnifiedDeployer, AllContracts } from "script/UnifiedDeployer.sol";
import { UniV3SwapAdapter } from "src/ports/swap_adapters/UniV3SwapAdapter.sol";


contract BaseTest is PRBTest, StdCheats, UnifiedDeployer {
    using SafeERC20 for IERC20;

    uint256 constant public TWO_DAYS = 6_400 * 2;
    address feeCollector = makeAddr("feeCollector");

    function initFork() internal {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 18_369_197 });

    }

    function initTestFramework() internal {
        wbtc = IERC20(WBTC);

        DeployAllContracts();

        allContracts.protocolParameters.setFeeCollector(feeCollector);
    }

    //erc721 receiver
    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function openETHBasedPosition(uint256 collateralAmount, uint256 borrowAmount) internal returns (uint256 nftId) {

        deal(WBTC, address(this), collateralAmount);
        ERC20(WBTC).approve(address(allContracts.positionOpener), type(uint256).max);

        bytes memory payload = getWBTCWETHUniswapPayload(); 

        PositionOpener.OpenPositionParams memory params = PositionOpener.OpenPositionParams({
            collateralAmount: collateralAmount,
            wbtcToBorrow: borrowAmount,
            minStrategyShares: 0,
            strategy: ETHPLUSETH_STRATEGY,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload
        });
         
        return allContracts.positionOpener.openPosition(params);
    }

    function liquidateETHPosition(uint256 nftId) internal returns (uint256 debtPaidBack) {
        uint256 fakeEthUsdPrice = 0;
        uint256 fakeBtcUsdPrice = 0;
        uint256 fakeBtcEthPrice = 0;

        {
            // Get current eth price
            uint256 ethUsdPrice = allContracts.ethUsdOracle.getLatestPrice();
            uint256 wtbcUsdPrice = allContracts.wbtcUsdOracle.getLatestPrice();

            // Drop the eth price by 20%
            fakeEthUsdPrice = (ethUsdPrice * 0.9e8) / 1e8;
            fakeBtcUsdPrice = (wtbcUsdPrice * 1.1e8) / 1e8;
            fakeBtcEthPrice = fakeBtcUsdPrice * 1e18 / fakeEthUsdPrice;

            FakeWBTCWETHSwapAdapter fakeSwapAdapter = new FakeWBTCWETHSwapAdapter();
            deal(WETH, address(fakeSwapAdapter), 1000e18);
            deal(WBTC, address(fakeSwapAdapter), 1000e8);
            fakeSwapAdapter.setWbtcToWethExchangeRate(fakeBtcEthPrice);
            fakeSwapAdapter.setWethToWbtcExchangeRate(1e36 / fakeBtcEthPrice);
            //allContracts.positionCloser.changeSwapAdapter(address(fakeSwapAdapter));
            allContracts.swapManager.setSwapAdapter(SwapManager.SwapRoute.UNISWAPV3, fakeSwapAdapter);
        }

        {
            FakeOracle fakeETHUSDOracle = new FakeOracle();
            fakeETHUSDOracle.updateFakePrice(fakeEthUsdPrice);
            fakeETHUSDOracle.updateDecimals(8);
            allContracts.oracleManager.setUSDOracle(WETH, fakeETHUSDOracle);
            FakeOracle fakeWBTCUSDOracle = new FakeOracle();
            fakeWBTCUSDOracle.updateFakePrice(fakeBtcUsdPrice);
            fakeWBTCUSDOracle.updateDecimals(8);
            allContracts.oracleManager.setUSDOracle(WBTC, fakeWBTCUSDOracle);
        }

        {
            // Liquidate position
            allContracts.positionCloser.setMonitor(address(this));
            uint256 wbtcVaultBalanceBefore = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
            allContracts.positionCloser.liquidatePosition(
                nftId, 0, SwapManager.SwapRoute.UNISWAPV3, getWBTCWETHUniswapPayload(), address(0)
            );
            uint256 wbtcVaultBalanceAfter = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
            debtPaidBack = wbtcVaultBalanceAfter - wbtcVaultBalanceBefore;
        }
    }

    function liquidateUSDCPosition(uint256 nftId) internal returns (uint256 debtPaidBack) {
        uint256 fakeBtcUsdPrice = 0;

        {
            // Get current eth price
            uint256 wtbcUsdPrice = allContracts.oracleManager.getLatestTokenPriceInUSD(WBTC);

            // Drop the eth price by 20%
            fakeBtcUsdPrice = (uint256(wtbcUsdPrice) * 1.3e8) / 1e8;

            FakeWBTCUSDCSwapAdapter fakeSwapAdapter = new FakeWBTCUSDCSwapAdapter();
            deal(USDC, address(fakeSwapAdapter), 100_000e6);
            deal(WBTC, address(fakeSwapAdapter), 1000e8);

            fakeSwapAdapter.setWbtcToUsdcExchangeRate(fakeBtcUsdPrice);
            fakeSwapAdapter.setUsdcToWbtcExchangeRate(1e16 / fakeBtcUsdPrice);
            //allContracts.positionCloser.changeSwapAdapter(address(fakeSwapAdapter));
            allContracts.swapManager.setSwapAdapter(SwapManager.SwapRoute.UNISWAPV3, fakeSwapAdapter);

        }

        {
            FakeOracle fakeWBTCUSDOracle = new FakeOracle();
            fakeWBTCUSDOracle.updateFakePrice(fakeBtcUsdPrice);
            fakeWBTCUSDOracle.updateDecimals(8);
            allContracts.oracleManager.setUSDOracle(WBTC, fakeWBTCUSDOracle);
        }

        {
            // Liquidate position
            allContracts.positionCloser.setMonitor(address(this));
            uint256 wbtcVaultBalanceBefore = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
            allContracts.positionCloser.liquidatePosition(
                nftId, 0, SwapManager.SwapRoute.UNISWAPV3, getUSDCWBTCUniswapPayload(), address(0)
            );
            uint256 wbtcVaultBalanceAfter = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
            debtPaidBack = wbtcVaultBalanceAfter - wbtcVaultBalanceBefore;
        }
    }

    function getWBTCWETHUniswapPayload() internal view returns (bytes memory) {
        
        bytes memory payload = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );

        return payload;
    }

    function closeETHBasedPosition(uint256 nftId) internal {
        vm.roll(block.number + TWO_DAYS);
        bytes memory payload = getWETHWBTCUniswapPayload();
        allContracts.positionCloser.closePosition(nftId, 0, SwapManager.SwapRoute.UNISWAPV3, payload, address(0));
    }

    function getWETHWBTCUniswapPayload() internal view returns (bytes memory) {
        bytes memory payload = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000
            })
        );

        return payload;
    }

    function openUSDCBasedPosition(uint256 collateralAmount, uint256 borrowAmount) internal returns (uint256 nftId) {
        deal(WBTC, address(this), collateralAmount);
        ERC20(WBTC).approve(address(allContracts.positionOpener), type(uint256).max);

        bytes memory payload = getWBTCUSDCUniswapPayload();

        PositionOpener.OpenPositionParams memory params = PositionOpener.OpenPositionParams({
            collateralAmount: collateralAmount,
            wbtcToBorrow: borrowAmount,
            minStrategyShares: 0,
            strategy: FRAXBPALUSD_STRATEGY,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload
        });
         
        return allContracts.positionOpener.openPosition(params);
    }

    function getWBTCUSDCUniswapPayload() internal view returns (bytes memory) {
        bytes memory payload = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(500), WETH, uint24(3000), USDC),
                deadline: block.timestamp + 1000
            })
        );

        return payload;
    }

      function closeUSDCBasedPosition(uint256 nftId) internal {
        vm.roll(block.number + TWO_DAYS);
        bytes memory payload = getUSDCWBTCUniswapPayload();
        allContracts.positionCloser.closePosition(nftId, 0, SwapManager.SwapRoute.UNISWAPV3, payload, address(0));
    }

    function getUSDCWBTCUniswapPayload() internal view returns (bytes memory) {
        bytes memory payload = abi.encode(
            UniV3SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(USDC, uint24(3000), WETH, uint24(500), WBTC),
                deadline: block.timestamp + 1000
            })
        );

        return payload;
    }
}
