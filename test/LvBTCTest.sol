// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import { IAccessControl } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

// solhint-disable-next-line no-global-import
import "test/BaseTest.sol";

import { FakeOracle } from "src/ports/oracles/FakeOracle.sol";

import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";

contract LvBTCTest is BaseTest {
    function setUp() public {
        initFork();
        initTestFramework();

        deal(WBTC, address(allContracts.wbtcVault), 100e8);
        ERC20(WBTC).approve(address(allContracts.positionOpener), type(uint256).max);
        ERC20(WBTC).approve(address(allContracts.positionCloser), type(uint256).max);
    }
}
