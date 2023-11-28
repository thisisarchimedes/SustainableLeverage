// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import { LeverageEngine } from "src/LeverageEngine.sol";

contract OracleTestHelper is LeverageEngine {
    function checkOracles(address token, uint256 wbtcAmount) external view returns (uint256) {
        return _checkOracles(token, wbtcAmount);
    }
}
