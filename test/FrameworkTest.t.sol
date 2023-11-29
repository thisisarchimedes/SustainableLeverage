// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";

contract FrameworkTest is BaseTest {
    function setUp() public virtual {
        initTestFramework();
    }

    function testStub() public {
        assertEq(true, true);
    }
}
