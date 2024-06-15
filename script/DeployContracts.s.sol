// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { console2 } from "forge-std/console2.sol";

import { BaseScript } from "script/Base.s.sol";
import { UnifiedDeployer, Environment } from "script/UnifiedDeployer.sol";

import { PositionToken } from "src/user_facing/PositionToken.sol";

import { LeverageDepositor } from "src/internal/LeverageDepositor.sol";
import { WBTCVault } from "src/internal/WBTCVault.sol";
import { LeveragedStrategy } from "src/internal/LeveragedStrategy.sol";

import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";

import { ChainlinkOracle } from "src/ports/oracles/ChainlinkOracle.sol";
import { BaseScript } from "script/Base.s.sol";

import { PositionLiquidator } from "src/monitor_facing/PositionLiquidator.sol";
import { PositionExpirator } from "src/monitor_facing/PositionExpirator.sol";

contract DeployContracts is UnifiedDeployer, BaseScript {
    address private constant KMS_URGENT_GLOBAL = 0x36b47D05EbCf3694b6c94Abc6002da727398422C;
    address private constant KMS_LEVERAGE_NORMAL = 0x0F32c97966FbBB661d1b1405838Ad3C9A3896697;
    address private constant KMS_PSP_NORMAL = 0x1d74A8F5e8452f1BB37EA85BBA0e68f54f0ad99F;

    function run() public broadcast {
        DeployAllContracts();

        CreateContractJSON();

        if(this.ENV() == Environment.FORK) {
            fundBalances();
            setAccessControl();
        }
    }

    function CreateContractJSON() internal {
        deployedContracts.push(dependencyAddresses.expiredVault);
        deployedContractsNames.push("ExpiredVault");

        deployedContracts.push(dependencyAddresses.leverageDepositor);
        deployedContractsNames.push("LeverageDepositor");

        deployedContracts.push(dependencyAddresses.wbtcVault);
        deployedContractsNames.push("wbtcVault");

        deployedContracts.push(dependencyAddresses.positionToken);
        deployedContractsNames.push("PositionToken");

        deployedContracts.push(dependencyAddresses.proxyAdmin);
        deployedContractsNames.push("ProxyAdmin");

        deployedContracts.push(dependencyAddresses.leveragedStrategy);
        deployedContractsNames.push("LeveragedStrategy");

        deployedContracts.push(dependencyAddresses.protocolParameters);
        deployedContractsNames.push("ProtocolParameters");

        deployedContracts.push(dependencyAddresses.oracleManager);
        deployedContractsNames.push("OracleManager");

        deployedContracts.push(dependencyAddresses.positionOpener);
        deployedContractsNames.push("PositionOpener");

        deployedContracts.push(dependencyAddresses.positionCloser);
        deployedContractsNames.push("PositionCloser");

        deployedContracts.push(dependencyAddresses.positionLiquidator);
        deployedContractsNames.push("PositionLiquidator");

        deployedContracts.push(dependencyAddresses.positionExpirator);
        deployedContractsNames.push("PositionExpirator");

        deployedContracts.push(dependencyAddresses.positionLedger);
        deployedContractsNames.push("PositionLedger");

        deployedContracts.push(dependencyAddresses.swapManager);
        deployedContractsNames.push("SwapManager");

        deployedContracts.push(dependencyAddresses.lvBTC);
        deployedContractsNames.push("LvBTC");

        deployedContracts.push(dependencyAddresses.lvBTCCurvePool);
        deployedContractsNames.push("lvBTCCurvePool");

        _writeDeploymentsToJson();
    }

    function fundBalances() internal {
        setWBTCBalanceForAddress(dependencyAddresses.wbtcVault);
        setWBTCBalanceForAddress(broadcaster);
    }

    function setAccessControl() internal {
        PositionLiquidator proxyPositionLiquidator = PositionLiquidator(this.getAllContracts().positionLiquidator);
        proxyPositionLiquidator.setMonitor(KMS_URGENT_GLOBAL);

        PositionExpirator proxyPositionExpirator = PositionExpirator(this.getAllContracts().positionExpirator);
        proxyPositionExpirator.setMonitor(KMS_LEVERAGE_NORMAL);
    }

    function setWBTCBalanceForAddress(address dest) internal {
        bytes32 storageSlot = keccak256(abi.encode(address(dest), 0));
        uint256 amount = 1_000_000e8;
        string[] memory inputs = new string[](5);
        inputs[0] = "python";
        inputs[1] = "script/setupFork.py";
        inputs[2] = vm.toString(storageSlot);
        inputs[3] = vm.toString(WBTC);
        inputs[4] = vm.toString(bytes32(amount));

        vm.ffi(inputs);
    }
}
