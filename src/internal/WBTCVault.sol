// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";

import { IWBTCVault } from "src/interfaces/IWBTCVault.sol";

//TODO implement this contract. This is just skeleton for test purposes
// TODO add access control
contract WBTCVault is IWBTCVault, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public immutable WBTC;

    constructor(address _wbtc) {
        WBTC = IERC20(_wbtc);
    }

    function borrowAmountTo(uint256 amount, address to) external override {
        WBTC.transfer(to, amount);
    }

    function repayDebt(uint256 nftId, uint256 amount) external {
        WBTC.safeTransferFrom(msg.sender, address(this), amount);
        emit EventsLeverageEngine.Repay(nftId, amount);
    }
}
