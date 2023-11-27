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
import { ExpiredVault } from "../src/ExpiredVault.sol";
import { FakeOracle } from "../src/ports/FakeOracle.sol";
import { FakeWBTCWETHSwapAdapter } from "../src/ports/FakeWBTCWETHSwapAdapter.sol";
import { ChainlinkOracle } from "../src/ports/ChainlinkOracle.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { ExpiredVault } from "src/ExpiredVault.sol";

contract BaseTest is PRBTest, StdCheats {
    address feeCollector = makeAddr("feeCollector");
    LeverageEngine internal leverageEngine;
    PositionToken internal positionToken;
    LeverageDepositor internal leverageDepositor;
    WBTCVault internal wbtcVault;
    ProxyAdmin internal proxyAdmin;
    IOracle internal oracle;
    TransparentUpgradeableProxy internal proxy;
    TransparentUpgradeableProxy internal expiredVaultProxy;
    SwapAdapter internal swapAdapter;
    ExpiredVault internal expiredVault;
    IERC20 internal wbtc;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant ETHPLUSETH_STRATEGY = 0xf3E920f099B19Ce604d672F0e87AAce490558fCA;
    address public constant WBTCUSDORACLE = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public constant ETHUSDORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDCUSDORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant BTCETHORACLE = 0xdeb288F737066589598e9214E782fa5A8eD689e8;
    address public constant FRAXBPALUSD_STRATEGY = 0xB888b8204Df31B54728e963ebA5465A95b695103;
    ChainlinkOracle ethUsdOracle;
    ChainlinkOracle btcEthOracle;
    ChainlinkOracle wbtcUsdOracle;

    function _prepareContracts() internal {
        proxyAdmin = new ProxyAdmin(address(this));
        positionToken = new PositionToken();
        leverageDepositor = new LeverageDepositor(WBTC,WETH);
        wbtcVault = new WBTCVault(WBTC);
        leverageEngine = new LeverageEngine();
        wbtc = IERC20(WBTC);
        swapAdapter = new SwapAdapter(WBTC, address(leverageDepositor));
        expiredVault = new ExpiredVault();
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
        bytes memory initDataExpiredVault =
            abi.encodeWithSelector(ExpiredVault.initialize.selector, address(leverageEngine), WBTC);
        expiredVault = ExpiredVault(
            address(new TransparentUpgradeableProxy(address(expiredVault),address(proxyAdmin),initDataExpiredVault))
        );

        ethUsdOracle = new ChainlinkOracle(ETHUSDORACLE);
        btcEthOracle = new ChainlinkOracle(BTCETHORACLE);
        wbtcUsdOracle = new ChainlinkOracle(WBTCUSDORACLE);
        leverageEngine.setOracle(WBTC, wbtcUsdOracle);
        leverageEngine.setOracle(WETH, ethUsdOracle);
        leverageEngine.setOracle(USDC, new ChainlinkOracle(USDCUSDORACLE));

        LeverageEngine.StrategyConfig memory strategyConfig = ILeverageEngine.StrategyConfig({
            quota: 100e8,
            maximumMultiplier: 3e8,
            positionLifetime: 1000,
            liquidationBuffer: 1.25e8,
            liquidationFee: 0.02e8
        });
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        leverageEngine.setStrategyConfig(FRAXBPALUSD_STRATEGY, strategyConfig);
        leverageEngine.setExpiredVault(address(expiredVault));
    }

    //erc721 receiver
    function onERC721Received(address, address, uint256, bytes memory) public returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function openETHBasedPosition(uint256 collateralAmount, uint256 borrowAmount) internal returns (uint256 nftId) {
        bytes memory payload = getWBTCWETHUniswapPayload();

        deal(WBTC, address(this), 1000e8);

        nftId = leverageEngine.openPosition(
            collateralAmount, borrowAmount, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
    }

    function liquidatePosition(uint256 nftId) internal returns (uint256 debtPaidBack) {
        uint256 fakeEthUsdPrice = 0;
        uint256 fakeBtcUsdPrice = 0;
        uint256 fakeBtcEthPrice = 0;

        {
            // Get current eth price
            (, int256 ethUsdPrice,,,) = ethUsdOracle.latestRoundData();
            (, int256 wtbcUsdPrice,,,) = wbtcUsdOracle.latestRoundData();

            // Drop the eth price by 20%
            fakeEthUsdPrice = (uint256(ethUsdPrice) * 0.9e8) / 1e8;
            fakeBtcUsdPrice = (uint256(wtbcUsdPrice) * 1.1e8) / 1e8;
            fakeBtcEthPrice = fakeBtcUsdPrice * 1e18 / fakeEthUsdPrice;

            FakeWBTCWETHSwapAdapter fakeSwapAdapter = new FakeWBTCWETHSwapAdapter();
            deal(WETH, address(fakeSwapAdapter), 1000e18);
            deal(WBTC, address(fakeSwapAdapter), 1000e8);
            fakeSwapAdapter.setWbtcToWethExchangeRate(fakeBtcEthPrice);
            fakeSwapAdapter.setWethToWbtcExchangeRate(1e36 / fakeBtcEthPrice);
            leverageEngine.changeSwapAdapter(address(fakeSwapAdapter));
        }

        {
            FakeOracle fakeETHUSDOracle = new FakeOracle();
            fakeETHUSDOracle.updateFakePrice(fakeEthUsdPrice);
            fakeETHUSDOracle.updateDecimals(8);
            leverageEngine.setOracle(WETH, fakeETHUSDOracle);
            FakeOracle fakeWBTCUSDOracle = new FakeOracle();
            fakeWBTCUSDOracle.updateFakePrice(fakeBtcUsdPrice);
            fakeWBTCUSDOracle.updateDecimals(8);
            leverageEngine.setOracle(WBTC, fakeWBTCUSDOracle);
        }

        {
            // Liquidate position
            uint256 wbtcVaultBalanceBefore = IERC20(WBTC).balanceOf(address(wbtcVault));
            leverageEngine.liquidatePosition(
                nftId, 0, SwapAdapter.SwapRoute.UNISWAPV3, getWBTCWETHUniswapPayload(), address(0)
            );
            uint256 wbtcVaultBalanceAfter = IERC20(WBTC).balanceOf(address(wbtcVault));
            debtPaidBack = wbtcVaultBalanceAfter - wbtcVaultBalanceBefore;
        }
    }

    function getWBTCWETHUniswapPayload() internal view returns (bytes memory payload) {
        payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );
    }

    function closeETHBasedPosition(uint256 nftId) internal {
        bytes memory payload = getWETHWBTCUniswapPayload();

        leverageEngine.closePosition(nftId, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0));
    }

    function getWETHWBTCUniswapPayload() internal view returns (bytes memory payload) {
        payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WETH, uint24(3000), WBTC),
                deadline: block.timestamp + 1000
            })
        );
    }

    function openUSDCBasedPosition(uint256 collateralAmount, uint256 borrowAmount) internal returns (uint256 nftId) {
        bytes memory payload = getWBTCWUSDCUniswapPayload();

        deal(WBTC, address(this), 1000e8);

        nftId = leverageEngine.openPosition(
            collateralAmount,
            borrowAmount,
            FRAXBPALUSD_STRATEGY,
            0,
            SwapAdapter.SwapRoute.UNISWAPV3,
            payload,
            address(0)
        );
    }

    function getWBTCWUSDCUniswapPayload() internal view returns (bytes memory payload) {
        payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(500), WETH, uint24(3000), USDC),
                deadline: block.timestamp + 1000
            })
        );
    }
}
