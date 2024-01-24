// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { IExpiredVault } from "src/interfaces/IExpiredVault.sol";
import { Constants } from "src/libs/Constants.sol";

import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";

import { PositionToken } from "src/user_facing/PositionToken.sol";

import { PositionLedger, PositionState } from "src/internal/PositionLedger.sol";

contract ExpiredVault is IExpiredVault, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using EventsLeverageEngine for *;
    using ErrorsLeverageEngine for *;
    using Constants for *;

    IERC20 internal wbtc;
    PositionToken internal positionToken;
    PositionLedger internal positionLedger;

    uint256 public balance;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();

        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);

        wbtc = IERC20(Constants.WBTC_ADDRESS);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        positionLedger = PositionLedger(dependencies.positionLedger);
        positionToken = PositionToken(dependencies.positionToken);

        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionOpener);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionCloser);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionLiquidator);
    }

    ///////////// Monitor functions /////////////

    /// @notice Deposits WBTC into the vault from expired or liquidated positions.
    /// @param amount Amount of WBTC to deposit into the vault.
    function deposit(uint256 amount) external onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE) {
        // Pull funds from the depositor
        wbtc.safeTransferFrom(msg.sender, address(this), amount);

        // Update the vault balance
        balance += amount;

        // Emit event
        emit EventsLeverageEngine.Deposit(msg.sender, amount);
    }

    ///////////// User functions /////////////

    /// @notice Allows users to claim their WBTC based on their position.
    /// @param nftId The ID of the NFT representing the position.
    function claim(uint256 nftId) external {
        uint256 claimableAmount = positionLedger.getClaimableAmount(nftId);
        revertIfPositionIsntClaimableBySender(nftId, claimableAmount);

        balance -= claimableAmount;

        positionLedger.claimableAmountWasClaimed(nftId);

        wbtc.safeTransfer(msg.sender, claimableAmount);

        positionToken.burn(nftId);

        emit EventsLeverageEngine.Claim(msg.sender, nftId, claimableAmount);
    }

    function revertIfPositionIsntClaimableBySender(uint256 nftId, uint256 claimableAmount) private view {
        if (positionToken.ownerOf(nftId) != msg.sender) revert ErrorsLeverageEngine.NotOwner();

        PositionState state = positionLedger.getPositionState(nftId);
        if (state != PositionState.EXPIRED && state != PositionState.LIQUIDATED) {
            revert ErrorsLeverageEngine.PositionNotExpiredOrLiquidated();
        }

        if (balance < claimableAmount) revert ErrorsLeverageEngine.InsufficientFunds();
        if (claimableAmount == 0) revert ErrorsLeverageEngine.PositionHasNoBalance();
    }
}
