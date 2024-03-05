// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { PositionToken } from "src/user_facing/PositionToken.sol";
import { ExpiredVault } from "src/user_facing/ExpiredVault.sol";
import { PositionOpener } from "src/user_facing/PositionOpener.sol";
import { PositionCloser } from "src/user_facing/PositionCloser.sol";

import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";

import { FakeOracle } from "src/ports/oracles/FakeOracle.sol";
import { FakeWBTCWETHSwapAdapter } from "src/ports/swap_adapters/FakeWBTCWETHSwapAdapter.sol";
import { FakeWBTCUSDCSwapAdapter } from "src/ports/swap_adapters/FakeWBTCUSDCSwapAdapter.sol";
import { ChainlinkOracle } from "src/ports/oracles/ChainlinkOracle.sol";
import { UniV3SwapAdapter } from "src/ports/swap_adapters/UniV3SwapAdapter.sol";

import "src/internal/LeverageDepositor.sol";
import { WBTCVault } from "src/internal/WBTCVault.sol";
import { ProtocolParameters } from "src/internal/ProtocolParameters.sol";
import { PositionLedger, LedgerEntry, PositionState } from "src/internal/PositionLedger.sol";
import { OracleManager } from "src/internal/OracleManager.sol";
import { LeveragedStrategy } from "src/internal/LeveragedStrategy.sol";
import { SwapManager } from "src/internal/SwapManager.sol";

import { PositionLiquidator } from "src/monitor_facing/PositionLiquidator.sol";
import { PositionExpirator } from "src/monitor_facing/PositionExpirator.sol";

import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";

import { LVBTC } from "src/LvBTC.sol";
import { ICurveStableswapFactoryNG } from "src/interfaces/ICurveStableswapFactoryNG.sol";
import { ICurvePool } from "src/interfaces/ICurvePool.sol";

struct AllContracts {
    PositionToken positionToken;
    LeverageDepositor leverageDepositor;
    WBTCVault wbtcVault;
    ProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy proxy;
    TransparentUpgradeableProxy expiredVaultProxy;
    ExpiredVault expiredVault;
    LeveragedStrategy leveragedStrategy;
    ProtocolParameters protocolParameters;
    PositionLedger positionLedger;
    PositionOpener positionOpener;
    PositionCloser positionCloser;
    PositionLiquidator positionLiquidator;
    PositionExpirator positionExpirator;
    OracleManager oracleManager;
    SwapManager swapManager;
    ChainlinkOracle ethUsdOracle;
    ChainlinkOracle btcEthOracle;
    ChainlinkOracle wbtcUsdOracle;
    ChainlinkOracle usdcUsdOracle;
    UniV3SwapAdapter uniV3SwapAdapter;
    LVBTC lvBTC;
    ICurvePool lvBTCCurvePool;
}

contract UnifiedDeployer {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;

    IERC20 internal wbtc;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant ETHPLUSETH_STRATEGY = 0xF326Cd46A1A189B305AFF7500b02C5C26b405266;
    address public constant WBTCUSDORACLE = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public constant ETHUSDORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDCUSDORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant BTCETHORACLE = 0xdeb288F737066589598e9214E782fa5A8eD689e8;
    address public constant FRAXBPALUSD_STRATEGY = 0xD078a331A8A00AB5391ba9f3AfC910225a78e6A1;
    address public constant CURVE_STABLE_FACTORY_NG_ADDRESS = 0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf;

    address admin;
    address defaultFeeCollector;
    address defaultPositionLiquidatorMonitor;
    address defaultPositionExpiratorMonitor;

    DependencyAddresses internal dependencyAddresses;

    AllContracts internal allContracts;

    function getDependecyAddresses() external view returns (DependencyAddresses memory) {
        return dependencyAddresses;
    }

    function getAllContracts() external view returns (AllContracts memory) {
        return allContracts;
    }

    function getAdminAddress() external view returns (address) {
        return admin;
    }

    function DeployAllContracts() public {
        admin = msg.sender; // TODO change hardcoded address before mainnet deployment
        defaultFeeCollector = msg.sender; // TODO change hardcoded address before mainnet deployment
        defaultPositionLiquidatorMonitor = msg.sender; // TODO change hardcoded address before mainnet deployment
        defaultPositionExpiratorMonitor = msg.sender; // TODO change hardcoded address before mainnet deployment

        createOracles();

        //deploy LvBTC
        allContracts.lvBTC = new LVBTC(address(this));

        //deploy LvBTC Curve pool

        deployProxyAndContracts();

        allContracts.expiredVault.setDependencies(dependencyAddresses);
        allContracts.leveragedStrategy.setDependencies(dependencyAddresses);
        allContracts.positionLedger.setDependencies(dependencyAddresses);
        allContracts.positionOpener.setDependencies(dependencyAddresses);
        allContracts.positionCloser.setDependencies(dependencyAddresses);
        allContracts.positionLiquidator.setDependencies(dependencyAddresses);
        allContracts.positionExpirator.setDependencies(dependencyAddresses);
        allContracts.positionToken.setDependencies(dependencyAddresses);
        allContracts.leverageDepositor.setDependencies(dependencyAddresses);
        allContracts.wbtcVault.setDependencies(dependencyAddresses);

        allowStrategiesWithDepositor();

        setStrategyConfig();
    }

    function createOracles() internal {
        allContracts.ethUsdOracle = new ChainlinkOracle(ETHUSDORACLE);
        allContracts.btcEthOracle = new ChainlinkOracle(BTCETHORACLE);
        allContracts.wbtcUsdOracle = new ChainlinkOracle(WBTCUSDORACLE);
        allContracts.usdcUsdOracle = new ChainlinkOracle(USDCUSDORACLE);
    }

    function allowStrategiesWithDepositor() internal {
        allContracts.leverageDepositor.allowStrategyWithDepositor(ETHPLUSETH_STRATEGY);
        allContracts.leverageDepositor.allowStrategyWithDepositor(FRAXBPALUSD_STRATEGY);
    }

    function setStrategyConfig() internal {
        LeveragedStrategy.StrategyConfig memory strategyConfig = LeveragedStrategy.StrategyConfig({
            quota: 10_000e8,
            maximumMultiplier: 3e8,
            positionLifetime: 3,
            liquidationBuffer: 1.25e8,
            liquidationFee: 0.02e8
        });
        allContracts.leveragedStrategy.setStrategyConfig(FRAXBPALUSD_STRATEGY, strategyConfig);
        allContracts.leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
    }

    function deployProxyAndContracts() internal {
        allContracts.proxyAdmin = new ProxyAdmin(admin);
        dependencyAddresses.proxyAdmin = address(allContracts.proxyAdmin);

        allContracts.positionToken = new PositionToken();
        dependencyAddresses.positionToken = address(allContracts.positionToken);

        allContracts.leverageDepositor = new LeverageDepositor();
        dependencyAddresses.leverageDepositor = address(allContracts.leverageDepositor);

        dependencyAddresses.wbtcVault = createProxiedWBTCVault();
        allContracts.wbtcVault = WBTCVault(dependencyAddresses.wbtcVault);

        dependencyAddresses.oracleManager = createProxiedOracleManager();
        allContracts.oracleManager = OracleManager(dependencyAddresses.oracleManager);

        dependencyAddresses.expiredVault = createProxiedExpiredVault();
        allContracts.expiredVault = ExpiredVault(dependencyAddresses.expiredVault);

        dependencyAddresses.leveragedStrategy = createProxiedStrategyManager();
        allContracts.leveragedStrategy = LeveragedStrategy(dependencyAddresses.leveragedStrategy);

        dependencyAddresses.protocolParameters = createProxiedProtocolParameters();
        allContracts.protocolParameters = ProtocolParameters(dependencyAddresses.protocolParameters);

        dependencyAddresses.positionOpener = createProxiedPositionOpener();
        allContracts.positionOpener = PositionOpener(dependencyAddresses.positionOpener);

        dependencyAddresses.positionCloser = createProxiedPositionCloser();
        allContracts.positionCloser = PositionCloser(dependencyAddresses.positionCloser);

        dependencyAddresses.positionLiquidator = createProxiedPositionLiquidator();
        allContracts.positionLiquidator = PositionLiquidator(dependencyAddresses.positionLiquidator);

        dependencyAddresses.positionLedger = createProxiedPositionLedger();
        allContracts.positionLedger = PositionLedger(dependencyAddresses.positionLedger);

        dependencyAddresses.positionExpirator = createProxiedPositionExpirator();
        allContracts.positionExpirator = PositionExpirator(dependencyAddresses.positionExpirator);

        dependencyAddresses.swapManager = createProxiedSwapManager();
        allContracts.swapManager = SwapManager(dependencyAddresses.swapManager);

        allContracts.lvBTC = new LVBTC(address(this));
        dependencyAddresses.lvBTC = address(allContracts.lvBTC);

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

        allContracts.lvBTCCurvePool = initdeployCurvePool(
            dependencyAddresses.lvBTC,
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

        dependencyAddresses.lvBtcCurvePool = address(allContracts.lvBTCCurvePool);
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

    function createProxiedExpiredVault() internal returns (address) {
        ExpiredVault implexpiredVault = new ExpiredVault();

        address addrexpiredVault = createUpgradableContract(
            implexpiredVault.initialize.selector, address(implexpiredVault), address(allContracts.proxyAdmin)
        );

        return addrexpiredVault;
    }

    function createProxiedStrategyManager() internal returns (address) {
        LeveragedStrategy implleveragedStrategys = new LeveragedStrategy();
        address addrleveragedStrategy = createUpgradableContract(
            implleveragedStrategys.initialize.selector,
            address(implleveragedStrategys),
            address(allContracts.proxyAdmin)
        );

        return addrleveragedStrategy;
    }

    function createProxiedProtocolParameters() internal returns (address) {
        ProtocolParameters implProtocolParameters = new ProtocolParameters();
        address addrProtocolParameters = createUpgradableContract(
            implProtocolParameters.initialize.selector,
            address(implProtocolParameters),
            address(allContracts.proxyAdmin)
        );
        ProtocolParameters proxyProtocolParameters = ProtocolParameters(addrProtocolParameters);
        proxyProtocolParameters.setFeeCollector(defaultFeeCollector);

        return addrProtocolParameters;
    }

    function createProxiedOracleManager() internal returns (address) {
        OracleManager implOracleManager = new OracleManager();
        address addrOracleManager = createUpgradableContract(
            implOracleManager.initialize.selector, address(implOracleManager), address(allContracts.proxyAdmin)
        );
        OracleManager proxyOracleManager = OracleManager(addrOracleManager);

        proxyOracleManager.setUSDOracle(WBTC, allContracts.wbtcUsdOracle);
        proxyOracleManager.setUSDOracle(WETH, allContracts.ethUsdOracle);
        proxyOracleManager.setUSDOracle(USDC, allContracts.usdcUsdOracle);
        proxyOracleManager.setETHOracle(WBTC, allContracts.btcEthOracle);

        return addrOracleManager;
    }

    function createProxiedPositionOpener() internal returns (address) {
        PositionOpener implPositionOpener = new PositionOpener();
        address addrPositionOpener = createUpgradableContract(
            implPositionOpener.initialize.selector, address(implPositionOpener), address(allContracts.proxyAdmin)
        );

        return addrPositionOpener;
    }

    function createProxiedPositionCloser() internal returns (address) {
        PositionCloser implPositionCloser = new PositionCloser();
        address addrPositionCloser = createUpgradableContract(
            implPositionCloser.initialize.selector, address(implPositionCloser), address(allContracts.proxyAdmin)
        );

        return addrPositionCloser;
    }

    function createProxiedPositionLiquidator() internal returns (address) {
        PositionLiquidator implPositionLiquidator = new PositionLiquidator();
        address addrPositionLiquidator = createUpgradableContract(
            implPositionLiquidator.initialize.selector,
            address(implPositionLiquidator),
            address(allContracts.proxyAdmin)
        );
        PositionLiquidator proxyPositionLiquidator = PositionLiquidator(addrPositionLiquidator);
        proxyPositionLiquidator.setMonitor(defaultPositionLiquidatorMonitor);

        return addrPositionLiquidator;
    }

    function createProxiedPositionExpirator() internal returns (address) {
        PositionExpirator implPositionExpirator = new PositionExpirator();

        address addrPositionExpirator = createUpgradableContract(
            implPositionExpirator.initialize.selector, address(implPositionExpirator), address(allContracts.proxyAdmin)
        );
        PositionExpirator proxyPositionExpirator = PositionExpirator(addrPositionExpirator);
        proxyPositionExpirator.setMonitor(defaultPositionExpiratorMonitor);

        return addrPositionExpirator;
    }

    function createProxiedPositionLedger() internal returns (address) {
        PositionLedger implPositionLedger = new PositionLedger();
        address addrPositionLedger = createUpgradableContract(
            implPositionLedger.initialize.selector, address(implPositionLedger), address(allContracts.proxyAdmin)
        );

        return addrPositionLedger;
    }

    function createProxiedWBTCVault() internal returns (address) {
        WBTCVault implWbtcVault = new WBTCVault();
        address addrWBTCVault = createUpgradableContract(
            implWbtcVault.initialize.selector, address(implWbtcVault), address(allContracts.proxyAdmin)
        );

        return addrWBTCVault;
    }

    function createProxiedSwapManager() internal returns (address) {
        SwapManager implSwapManager = new SwapManager();
        address addrSwapManager = createUpgradableContract(
            implSwapManager.initialize.selector, address(implSwapManager), address(allContracts.proxyAdmin)
        );

        SwapManager proxySwapManager = SwapManager(addrSwapManager);
        proxySwapManager.setSwapAdapter(SwapManager.SwapRoute.UNISWAPV3, new UniV3SwapAdapter());

        return addrSwapManager;
    }

    function createUpgradableContract(
        bytes4 selector,
        address implementationAddress,
        address proxyAddress
    )
        internal
        returns (address)
    {
        bytes memory initData = abi.encodeWithSelector(selector);

        TransparentUpgradeableProxy proxied =
            new TransparentUpgradeableProxy(implementationAddress, proxyAddress, initData);

        return address(proxied);
    }
}
