// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { PositionToken } from "src/PositionToken.sol";
import "src/LeverageDepositor.sol";
import { WBTCVault } from "src/WBTCVault.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { SwapAdapter } from "src/SwapAdapter.sol";
import { ExpiredVault } from "src/ExpiredVault.sol";
import { FakeOracle } from "src/ports/FakeOracle.sol";
import { FakeWBTCWETHSwapAdapter } from "../src/ports/FakeWBTCWETHSwapAdapter.sol";
import { FakeWBTCUSDCSwapAdapter } from "../src/ports/FakeWBTCUSDCSwapAdapter.sol";
import { ChainlinkOracle } from "src/ports/ChainlinkOracle.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { ProtocolParameters } from "src/ProtocolParameters.sol";
import { PositionLedger, LedgerEntry, PositionState } from "src/PositionLedger.sol";
import { PositionOpener } from "src/PositionOpener.sol";
import { PositionCloser } from "src/PositionCloser.sol";
import { OracleManager } from "src/OracleManager.sol";
import { LeveragedStrategy } from "src/LeveragedStrategy.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";


struct AllContracts {
    PositionToken  positionToken;
    LeverageDepositor  leverageDepositor;
    WBTCVault  wbtcVault;
    ProxyAdmin  proxyAdmin;
    TransparentUpgradeableProxy  proxy;
    TransparentUpgradeableProxy  expiredVaultProxy;
    SwapAdapter swapAdapter;
    ExpiredVault expiredVault;
    LeveragedStrategy leveragedStrategy;
    ProtocolParameters protocolParameters;
    PositionLedger positionLedger;
    PositionOpener positionOpener;
    PositionCloser positionCloser;
    OracleManager oracleManager;

    ChainlinkOracle ethUsdOracle;
    ChainlinkOracle btcEthOracle;
    ChainlinkOracle wbtcUsdOracle;
}

contract UnifiedDeployer {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    
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

    address defaultFeeCollector = address(0);
    address admin;

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

        createOracles();

        deployProxyAndContracts();

        allContracts.expiredVault.setDependencies(dependencyAddresses);
        allContracts.leveragedStrategy.setDependencies(dependencyAddresses);
        allContracts.positionLedger.setDependencies(dependencyAddresses);
        allContracts.positionOpener.setDependencies(dependencyAddresses);
        allContracts.positionCloser.setDependencies(dependencyAddresses);
        allContracts.positionToken.setDependencies(dependencyAddresses);

        admin = msg.sender;
    }

    function createOracles() internal {
        allContracts.ethUsdOracle = new ChainlinkOracle(ETHUSDORACLE);
        allContracts.btcEthOracle = new ChainlinkOracle(BTCETHORACLE);
        allContracts.wbtcUsdOracle = new ChainlinkOracle(WBTCUSDORACLE);
    }

    function deployProxyAndContracts() internal {
        allContracts.proxyAdmin = new ProxyAdmin(address(this));
        dependencyAddresses.proxyAdmin = address(allContracts.proxyAdmin);

        allContracts.positionToken = new PositionToken();
        dependencyAddresses.positionToken = address(allContracts.positionToken);

        allContracts.wbtcVault = new WBTCVault(WBTC);
        dependencyAddresses.wbtcVault = address(allContracts.wbtcVault);

        allContracts.leverageDepositor = new LeverageDepositor(WBTC, WETH);
        dependencyAddresses.leverageDepositor = address(allContracts.leverageDepositor);

        allContracts.swapAdapter = new SwapAdapter(WBTC, address(allContracts.leverageDepositor));
        dependencyAddresses.swapAdapter = address(allContracts.swapAdapter);

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

        dependencyAddresses.positionLedger = createProxiedPositionLedger();
        allContracts.positionLedger = PositionLedger(dependencyAddresses.positionLedger);
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
            implleveragedStrategys.initialize.selector, address(implleveragedStrategys), address(allContracts.proxyAdmin)
        );
        LeveragedStrategy proxyleveragedStrategys = LeveragedStrategy(addrleveragedStrategy);

        LeveragedStrategy.StrategyConfig memory strategyConfig = LeveragedStrategy.StrategyConfig({
            quota: 100e8,
            maximumMultiplier: 3e8,
            positionLifetime: 1000,
            liquidationBuffer: 1.25e8,
            liquidationFee: 0.02e8
        });
        proxyleveragedStrategys.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
        proxyleveragedStrategys.setStrategyConfig(FRAXBPALUSD_STRATEGY, strategyConfig);

        return addrleveragedStrategy;
    }

    function createProxiedProtocolParameters() internal returns (address) {
        ProtocolParameters implProtocolParameters = new ProtocolParameters();
        address addrProtocolParameters = createUpgradableContract(
            implProtocolParameters.initialize.selector, address(implProtocolParameters), address(allContracts.proxyAdmin)
        );
        ProtocolParameters proxylProtocolParameters = ProtocolParameters(addrProtocolParameters);

        proxylProtocolParameters.setFeeCollector(defaultFeeCollector);

        return addrProtocolParameters;
    }

    function createProxiedOracleManager() internal returns (address) {
        OracleManager implOracleManager = new OracleManager();
        address addrOracleManager = createUpgradableContract(
            implOracleManager.initialize.selector, address(implOracleManager), address(allContracts.proxyAdmin)
        );
        OracleManager proxyOracleManager = OracleManager(addrOracleManager);

        proxyOracleManager.setOracle(WBTC, new ChainlinkOracle(WBTCUSDORACLE));
        proxyOracleManager.setOracle(WETH, new ChainlinkOracle(ETHUSDORACLE));
        proxyOracleManager.setOracle(USDC, new ChainlinkOracle(USDCUSDORACLE));

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

    function createProxiedPositionLedger() internal returns (address) {
        PositionLedger implPositionLedger = new PositionLedger();
        address addrPositionLedger = createUpgradableContract(
            implPositionLedger.initialize.selector, address(implPositionLedger), address(allContracts.proxyAdmin)
        );

        return addrPositionLedger;
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
  
