// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { LVBTC } from "../LvBTC.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { EventsLeverageEngine } from "../libs/EventsLeverageEngine.sol";
import { ICurvePool } from "../interfaces/ICurvePool.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";

import { IWBTCVault } from "src/interfaces/IWBTCVault.sol";

//TODO implement this contract. This is just skeleton for test purposes
// TODO add access control
contract WBTCVault is IWBTCVault, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    int128 private immutable WBTC_INDEX = 0;
    int128 private immutable LVBTC_INDEX = 1;

    IERC20 private immutable wBtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    LVBTC private lvBtc;
    ICurvePool private curvePool;

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
        _grantRole(ProtocolRoles.MONITOR_ROLE, msg.sender);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        lvBtc = LVBTC(dependencies.lvBTC);
        curvePool = ICurvePool(dependencies.lvBtcCurvePool);

        wBtc.approve(address(dependencies.lvBtcCurvePool), type(uint256).max);
        lvBtc.approve(address(dependencies.lvBtcCurvePool), type(uint256).max);

        // TODO: add these roles and also access control on borrowAmountTo and repayDebt
        // _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionOpener);
        // _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionCloser);
        // _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionLiquidator);
        // _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionExpirator);
    }

    function swapToLVBTC(uint256 amount, uint256 minAmount) external onlyRole(ProtocolRoles.MONITOR_ROLE) {
        curvePool.exchange(WBTC_INDEX, LVBTC_INDEX, amount, minAmount, address(this));
        uint256 lvBTCBalance = lvBtc.balanceOf(address(this));

        lvBtc.burn(lvBTCBalance);
    }

    function borrowAmountTo(uint256 amount, address to) external {
        wBtc.transfer(to, amount);
    }

    function repayDebt(uint256 nftId, uint256 amount) external {
        wBtc.safeTransferFrom(msg.sender, address(this), amount);
        emit EventsLeverageEngine.Repay(nftId, amount);
    }
}
