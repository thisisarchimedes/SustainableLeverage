// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { SwapManager } from "src/SwapManager.sol";

struct OpenPositionParams {
    uint256 collateralAmount;
    uint256 wbtcToBorrow;
    address strategy;
    uint256 minStrategyShares;
    SwapManager.SwapRoute swapRoute;
    bytes swapData;
    address exchange;
}

struct ClosePositionParams {
    uint256 nftId;
    uint256 minWBTC;
    SwapManager.SwapRoute swapRoute;
    bytes swapData;
    address exchange;
}