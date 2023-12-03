// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21 <0.9.0;

import { Script } from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    /* solhint-disable  */
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;
    address[] internal deployedContracts;
    string[] internal deployedContractsNames;
    string out;

    constructor() {
        broadcaster = vm.rememberKey(vm.envUint("DEPLOYER_PKEY"));
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    /* solhint-disable  */
    function _writeDeploymentsToJson() internal {
        out = "";
        line("[");
        for (uint256 i = 0; i < deployedContracts.length; ++i) {
            bool end = i + 1 == deployedContracts.length;
            line("  {");
            line(string.concat('    "address": "', vm.toString(deployedContracts[i]), '",'));
            line(string.concat('    "name": "', deployedContractsNames[i], '"'));
            line(end ? "  }" : "  },");
        }
        /* solhint-enable  */
        line("]");
        string memory mainFile =
            string.concat(vm.projectRoot(), "/deployments/", vm.toString(block.chainid), "-deployments.json");
        vm.writeFile(mainFile, out);
    }

    function line(string memory s) internal {
        out = string.concat(out, s, "\n");
    }
}
