// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { ILeverageDepositor } from "../interfaces/ILeverageDepositor.sol";

contract LeverageDepositorMock is ILeverageDepositor {
    function deposit(address strategy, SwapRoute route, uint256 amount) external returns (uint256 receivedShares) {
        receivedShares = 100e18;
    }
}
