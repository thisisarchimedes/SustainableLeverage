// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { BaseScript } from "./Base.s.sol";
import { PositionToken } from "../src/PositionToken.sol";
import "../src/LeverageDepositor.sol";
import { WBTCVault } from "src/WBTCVault.sol";
import { ILeverageEngine } from "src/interfaces/ILeverageEngine.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { ProxyAdmin } from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { SwapAdapter } from "../src/SwapAdapter.sol";
import { ChainlinkOracle } from "../src/ports/ChainlinkOracle.sol";
import { console2 } from "forge-std/console2.sol";
import { UnifiedDeployer } from "script/UnifiedDeployer.sol";
import { LeveragedStrategy } from "src/LeveragedStrategy.sol";

contract DeployContracts is BaseScript, UnifiedDeployer {
    

    // TODO: Use BaseTest initalization here (setDependecies)
    function run() public broadcast {
       
        DeployAllContracts();
        
        CreateContractJSON();

        postDeployconfig();
    }

    function CreateContractJSON() internal {
        
        deployedContracts.push(dependencyAddresses.expiredVault);
        deployedContracts.push(dependencyAddresses.leverageDepositor);
        deployedContracts.push(dependencyAddresses.positionToken);
        deployedContracts.push(dependencyAddresses.wbtcVault);
        deployedContracts.push(dependencyAddresses.proxyAdmin);
        deployedContracts.push(dependencyAddresses.swapAdapter);
        deployedContracts.push(dependencyAddresses.leveragedStrategy);
        deployedContracts.push(dependencyAddresses.protocolParameters);
        deployedContracts.push(dependencyAddresses.oracleManager);
        deployedContracts.push(dependencyAddresses.positionOpener);
        deployedContracts.push(dependencyAddresses.positionCloser);
        deployedContracts.push(dependencyAddresses.positionLedger);

        deployedContractsNames.push("LeverageEngine");
        
        _writeDeploymentsToJson();
    }

    function postDeployconfig() internal {
        if (block.chainid == 1337) {
            LeveragedStrategy.StrategyConfig memory strategyConfig = LeveragedStrategy.StrategyConfig({
                quota: 10_000e8,
                maximumMultiplier: 3e8,
                positionLifetime: 1000,
                liquidationBuffer: 1.25e8,
                liquidationFee: 0.02e8
            });

            allContracts.leveragedStrategy.setStrategyConfig(FRAXBPALUSD_STRATEGY, strategyConfig);
            bytes32 storageSlot = keccak256(abi.encode(address(allContracts.wbtcVault), 0));
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
}
