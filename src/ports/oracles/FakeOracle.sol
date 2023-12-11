// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IOracle } from "src/interfaces/IOracle.sol";

contract FakeOracle is IOracle {
    uint256 fakePrice;
    uint8 fakeDecimals;

    function decimals() external view returns (uint8) {
        return fakeDecimals;
    }

    function updateDecimals(uint8 _decimals) external {
        fakeDecimals = _decimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, int256(fakePrice), 0, 0, 0);
    }

    function updateFakePrice(uint256 newPrice) external {
        fakePrice = newPrice;
    }
}
