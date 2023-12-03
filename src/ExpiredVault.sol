// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./interfaces/IExpiredVault.sol";
import { ProtocolRoles } from "./libs/ProtocolRoles.sol";
import { DependencyAddresses } from "./libs/DependencyAddresses.sol";
import { PositionToken } from "./PositionToken.sol";
import { PositionLedger, PositionState } from "src/PositionLedger.sol";
import { ErrorsLeverageEngine } from "./libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "./libs/EventsLeverageEngine.sol";

import { console2 } from "forge-std/console2.sol";

/// @title ExpiredVault Contract
/// @notice This contract holds the expired positions' funds and enables withdrawal of funds by users
/// against the NFT representing their position.
/// @dev This contract is upgradeable
contract ExpiredVault is IExpiredVault, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using EventsLeverageEngine for *;
    using ErrorsLeverageEngine for *;

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

        wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        positionLedger = PositionLedger(dependencies.positionLedger);
        positionToken = PositionToken(dependencies.positionToken);

        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionOpener);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionCloser);
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
