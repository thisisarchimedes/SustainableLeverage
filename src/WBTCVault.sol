// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IWBTCVault } from "./interfaces/IWBTCVault.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

//TODO implement this contract. This is just skeleton for test purposes
// TODO add access control
contract WBTCVault is IWBTCVault, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 immutable wbtc;

    event Repay(uint256 indexed nftId, uint256 amount);

    constructor(address _wbtc) {
        wbtc = IERC20(_wbtc);
    }
    function borrowAmountTo(uint256 amount, address to) external override {
        wbtc.transfer(to, amount);
    }

    function repay(uint256 nftId, uint256 amount) external {
        wbtc.safeTransferFrom(msg.sender, address(this), amount);
        emit Repay(nftId, amount);
    }
}
