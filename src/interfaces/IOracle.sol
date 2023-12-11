// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

interface IOracle {
    
    function decimals() external view returns (uint8);

    function getLatestPrice() external view returns (uint256);
}
