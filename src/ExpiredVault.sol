// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/ILeverageEngine.sol";
import "./interfaces/IExpiredVault.sol";
import "./PositionLedgerLib.sol";

/// @title ExpiredVault Contract
/// @notice This contract holds the expired positions' funds and enables withdrawal of funds by users
/// against the NFT representing their position.
/// @dev This contract is upgradeable
contract ExpiredVault is IExpiredVault, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    // Errors
    error InsufficientFunds();

    // Events
    event Deposit(address indexed depositor, uint256 amount);
    event Claim(address indexed claimer, uint256 indexed nftID, uint256 amount);

    // Define roles
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");

    // WBTC token
    IERC20 public wbtc;

    // Vault's balance
    uint256 public balance;

    // Leverage Engine
    ILeverageEngine public leverageEngine;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _leverageEngine, address _wbtc) external initializer {
        __AccessControl_init();
        leverageEngine = ILeverageEngine(_leverageEngine);
        _grantRole(MONITOR_ROLE, _leverageEngine);
        wbtc = IERC20(_wbtc);
    }

    ///////////// Monitor functions /////////////

    /// @notice Deposits WBTC into the vault from expired or liquidated positions.
    /// @param amount Amount of WBTC to deposit into the vault.
    function deposit(uint256 amount) external onlyRole(MONITOR_ROLE) {
        // Pull funds from the depositor
        wbtc.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update the vault balance
        balance += amount;

        // Emit event
        emit Deposit(msg.sender, amount);
    }

    ///////////// User functions /////////////

    /// @notice Allows users to claim their WBTC based on their position.
    /// @param nftID The ID of the NFT representing the position.
    function claim(uint256 nftID) external {
        PositionLedgerLib.LedgerEntry memory position = leverageEngine.getPosition(nftID);

        if(balance < position.claimableAmount) revert InsufficientFunds();

        // Update the vault balance
        balance -= position.claimableAmount;

        // Transfer the claimable amount to the user
        if (position.claimableAmount > 0) {
            wbtc.safeTransfer(msg.sender, position.claimableAmount);
        }

        // Update the ledger entry for this position
        // Checks the ownership of the NFT and reverts if the caller is not the owner
        // Checks the position state as well
        leverageEngine.closeExpiredPosition(nftID, msg.sender);

        // Emit event
        emit Claim(msg.sender, nftID, position.claimableAmount);
    }
}
