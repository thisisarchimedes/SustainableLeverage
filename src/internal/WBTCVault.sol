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

contract WBTCVault is IWBTCVault, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;

    int128 private immutable WBTC_INDEX = 0;
    int128 private immutable LVBTC_INDEX = 1;

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
    }

    function swapWBTCtolvBTC(uint256 amount, uint256 minAmount) external onlyRole(ProtocolRoles.MONITOR_ROLE) {
        curvePool.exchange(WBTC_INDEX, LVBTC_INDEX, amount, minAmount, address(this));
        uint256 lvBTCBalance = lvBtc.balanceOf(address(this));

        lvBtc.burn(lvBTCBalance);
    }

    function swaplvBTCtoWBTC(uint256 amount, uint256 minAmount) external onlyRole(ProtocolRoles.MONITOR_ROLE) {
        uint256 currentAmount = lvBtc.balanceOf(address(this));

        uint256 amountToMint = amount - currentAmount;
        lvBtc.mint(amountToMint);
        lvBtc.approve(address(curvePool), type(uint256).max);

        curvePool.exchange(LVBTC_INDEX, WBTC_INDEX, amount, minAmount, address(this));
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
