// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IOracle } from "src/interfaces/IOracle.sol";

contract FakeOracle is IOracle {
    uint256 public fakePrice;
    uint8 public fakeDecimals;

    function decimals() external view returns (uint8) {
        return fakeDecimals;
    }

    function updateDecimals(uint8 _decimals) external {
        fakeDecimals = _decimals;
    }

    function getLatestPrice() external view returns (uint256) {
        return fakePrice;
    }

    function updateFakePrice(uint256 newPrice) external {
        fakePrice = newPrice;
    }
}
