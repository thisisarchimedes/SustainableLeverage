// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IWBTCVault } from "../interfaces/IWBTCVault.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract WBTCVaultMock is IWBTCVault {
    IERC20 public wbtc;

    constructor() {
        wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    }

    function borrow(uint256 amount) external override {
        wbtc.transfer(msg.sender, amount);
    }
}
