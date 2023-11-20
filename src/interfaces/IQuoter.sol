    // SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;
pragma abicoder v2;

interface IQuoter {
    function quoteExactInput(bytes memory path, uint256 amountIn) external view returns (uint256 amountOut);
}
