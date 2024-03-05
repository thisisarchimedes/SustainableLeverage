pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./PositionLedgerLib.sol";

contract ExpiredVault is IExpiredVault, AccessControl {
    using SafeMath for uint256;

    IERC20 internal wbtc;
    PositionLedgerLib.LedgerStorage internal ledger;

    // Define roles
    // TODO: use ProtocolRoles instead
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");

    constructor(IERC20 _wbtc, PositionLedgerLib.LedgerStorage _ledger) {
        wbtc = _wbtc;
        ledger = _ledger;
        _setupRole(MONITOR_ROLE, msg.sender);
    }

    ///////////// Monitor functions /////////////

    /// @notice Deposits WBTC into the vault from expired or liquidated positions.
    /// @param amount Amount of WBTC to deposit into the vault.
    function deposit(uint256 amount) external  onlyRole(MONITOR_ROLE) {
        require(wbtc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    ///////////// User functions /////////////

    /// @notice Allows users to claim their WBTC based on their position.
    /// @param nftID The ID of the NFT representing the position.
    function claim(uint256 nftID) external  {
        PositionLedgerLib.LedgerEntry memory position = ledger.getLedgerEntry(nftID);
        
        require(position.state == PositionLedgerLib.PositionState.EXPIRED, "Position is not in EXPIRED state");
        require(position.claimable > 0, "No amount to claim for this position");
        require(wbtc.balanceOf(address(this)) >= position.claimable, "Not enough WBTC in the vault");
        
        // Transfer the claimable amount to the user
        wbtc.transfer(msg.sender, position.claimable);

        // Update the ledger entry for this position
        position.state = PositionLedgerLib.PositionState.CLOSED;
        position.claimable = 0;
        ledger.setLedgerEntry(nftID, position);

        // Burn the NFT (this would require integration with the NFT contract)
        // nft.burn(nftID);
    }
}
