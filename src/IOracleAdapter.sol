// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

interface IOracleAdapter{

     function setOracle(address token, address oracle);
     function getLastPrice(address token) view returns (uint256);
     function getOracleDecimalsForToken(address token) view returns(uint8);

}