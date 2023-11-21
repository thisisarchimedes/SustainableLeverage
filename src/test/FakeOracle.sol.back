// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IOracleAdapter } from "../interfaces/IOracleAdapter.sol";


contract FakeOracleAdapter is IOracleAdapter{

    mapping(address=>uint) public tokenPrices;

    function updatePrice(address token, uint newPrice)external{
         tokenPrices[token] = newPrice;
    }

    function getLastPrice(address token) view returns(uint256){
        return tokenPrices[token];
    }

    function getOracleDecimalsForToken(address token) view returns (uint8){
        return 8;
    }
}