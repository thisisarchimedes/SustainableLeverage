// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IWBTCVault } from "./interfaces/IWBTCVault.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

///TODO implement this contract. This is just skeleton for test purposes
contract WBTCVault is IWBTCVault {
    IERC20 immutable wbtc;

    constructor(address _wbtc) {
        wbtc = IERC20(_wbtc);
    }

    function borrow(uint256 amount) external override {
        wbtc.transfer(msg.sender, amount);
    }
}
