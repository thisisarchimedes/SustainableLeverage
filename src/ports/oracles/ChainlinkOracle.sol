// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { IOracle } from "src/interfaces/IOracle.sol";

contract ChainlinkOracle is IOracle {
    AggregatorV3Interface internal chainlinkOracleInstance;

    constructor(address _oracle) {
        chainlinkOracleInstance = AggregatorV3Interface(_oracle);
    }

    function decimals() external view returns (uint8) {
        return chainlinkOracleInstance.decimals();
    }

    function getLatestPrice() external view returns (uint256) {
        (, int256 price,,,) = chainlinkOracleInstance.latestRoundData();

        return uint256(price);
    }
}
