// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";
import { IOracle } from "../interfaces/IOracle.sol";

contract ChainlinkOracle is IOracle {
    AggregatorV3Interface internal chainlinkOracleInstance;

    constructor(address _oracle) {
        chainlinkOracleInstance = AggregatorV3Interface(_oracle);
    }

    function decimals() external view returns (uint8) {
        return chainlinkOracleInstance.decimals();
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return chainlinkOracleInstance.latestRoundData();
    }
}
