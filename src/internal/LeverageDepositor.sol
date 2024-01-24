// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { AccessControl } from "openzeppelin-contracts/access/AccessControl.sol";

import { ILeverageDepositor } from "src/interfaces/ILeverageDepositor.sol";
import { IMultiPoolStrategy } from "src/interfaces/IMultiPoolStrategy.sol";

import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";

// @notice: This contract holds strategy shares and deposit/withdraw tokens from strategy
contract LeverageDepositor is ILeverageDepositor, AccessControl {
    using ProtocolRoles for *;

    constructor() {
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionOpener);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionCloser);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionLiquidator);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionExpirator);
    }

    function allowStrategyWithDepositor(address strategy) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        IERC20(IMultiPoolStrategy(strategy).asset()).approve(strategy, type(uint256).max);
    }

    function denyStrategyWithDepositor(address strategy) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        IERC20(IMultiPoolStrategy(strategy).asset()).approve(strategy, 0);
    }

    function deposit(
        address strategy,
        uint256 amount
    )
        external
        onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE)
        returns (uint256)
    {
        if (amount <= 0) {
            revert ErrorsLeverageEngine.AmountMustBeGreaterThanZero();
        }

        return IMultiPoolStrategy(strategy).deposit(amount, address(this));
    }

    function redeem(
        address strategy,
        uint256 shares
    )
        external
        onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE)
        returns (uint256)
    {
        if (shares <= 0) {
            revert ErrorsLeverageEngine.AmountMustBeGreaterThanZero();
        }

        return IMultiPoolStrategy(strategy).redeem(shares, msg.sender, address(this), 0);
    }
}
