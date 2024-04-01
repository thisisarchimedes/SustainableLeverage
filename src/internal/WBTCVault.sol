// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { LVBTC } from "src/LvBTC.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";
import { ICurvePool } from "src/interfaces/ICurvePool.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { IWBTCVault } from "src/interfaces/IWBTCVault.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { Constants } from "src/libs/Constants.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";

contract WBTCVault is IWBTCVault, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;

    int128 public constant WBTC_INDEX = 0;
    int128 public constant LVBTC_INDEX = 1;

    IERC20 public wbtc;
    LVBTC private lvBtc;
    ICurvePool private curvePool;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
        _grantRole(ProtocolRoles.MONITOR_ROLE, msg.sender);
        _setRoleAdmin(ProtocolRoles.ADMIN_ROLE, ProtocolRoles.ADMIN_ROLE);
        _setRoleAdmin(ProtocolRoles.MONITOR_ROLE, ProtocolRoles.ADMIN_ROLE);
        _setRoleAdmin(ProtocolRoles.MINTER_ROLE, ProtocolRoles.ADMIN_ROLE);

        wbtc = IERC20(Constants.WBTC_ADDRESS);
    }

    function setlvBTCPoolAddress(address lvBTCPoolAddress) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        curvePool = ICurvePool(lvBTCPoolAddress);
        wbtc.approve(address(lvBTCPoolAddress), type(uint256).max);
        lvBtc.approve(address(lvBTCPoolAddress), type(uint256).max);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        lvBtc = LVBTC(dependencies.lvBTC);

        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionOpener);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionCloser);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionLiquidator);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionExpirator);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.lvBTC);
    }

    function swapWBTCtolvBTC(
        uint256 wbtcAmount,
        uint256 minlvBTCAmount
    )
        external
        onlyRole(ProtocolRoles.MONITOR_ROLE)
    {
        uint256 lvBTCBalanceBeforeSwap = lvBtc.balanceOf(address(this));

        curvePool.exchange(WBTC_INDEX, LVBTC_INDEX, wbtcAmount, minlvBTCAmount, address(this));
        uint256 lvBTCBalanceAfterSwap = lvBtc.balanceOf(address(this));

        uint256 totalToBurn = lvBTCBalanceAfterSwap - lvBTCBalanceBeforeSwap;

        lvBtc.burn(totalToBurn);
    }

    function swaplvBTCtoWBTC(
        uint256 lvBTCAmount,
        uint256 minWBTCAmount
    )
        external
        onlyRole(ProtocolRoles.MONITOR_ROLE)
    {
        uint256 currentlvBTCAmount = lvBtc.balanceOf(address(this));

        if (currentlvBTCAmount < lvBTCAmount) {
            revert ErrorsLeverageEngine.NotEnoughLvBTC();
        }

        curvePool.exchange(LVBTC_INDEX, WBTC_INDEX, lvBTCAmount, minWBTCAmount, address(this));
    }

    function borrowAmountTo(
        uint256 amount,
        address to
    )
        external
        override
        onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE)
    {
        wbtc.transfer(to, amount);
    }

    function repayDebt(uint256 nftId, uint256 amount) external {
        wbtc.safeTransferFrom(msg.sender, address(this), amount);
        emit EventsLeverageEngine.Repay(nftId, amount);
    }
}
