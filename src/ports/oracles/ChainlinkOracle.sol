// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { IOracle } from "src/interfaces/IOracle.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";

contract ChainlinkOracle is IOracle {
    AggregatorV3Interface internal chainlinkOracleInstance;
    uint256 public priceStaleThreshold;

    constructor(address _oracle, uint256 _priceStaleThreshold) {
        chainlinkOracleInstance = AggregatorV3Interface(_oracle);
        priceStaleThreshold = _priceStaleThreshold;
    }

    function decimals() external view returns (uint8) {
        return chainlinkOracleInstance.decimals();
    }

    function getLatestPrice() external view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = chainlinkOracleInstance.latestRoundData();

        if (updatedAt + priceStaleThreshold < block.timestamp) revert ErrorsLeverageEngine.OraclePriceStale();
        if (price <= 0) revert ErrorsLeverageEngine.OracleNegativePrice();
        return uint256(price);
    }
}
