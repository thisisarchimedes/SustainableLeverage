// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface ISwapAdapter {

    struct SwapWbtcParams {
        IERC20 otherToken;
        uint256 fromAmount;
        bytes payload;
        address recipient;
    }
   
    function swapToWbtc(SwapWbtcParams calldata params) external returns (uint256);

    function swapFromWbtc(SwapWbtcParams calldata params) external returns (uint256);
}
