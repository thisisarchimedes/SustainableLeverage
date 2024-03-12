pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract lvBTC is ERC20, AccessControl {
    using SafeMath for uint256;

    // Define roles
    // TODO: use ProtocolRoles instead 
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // State variable for approved mint destinations
    mapping(address => bool) private _approvedMintDestinations;

    // Define events
    event Minted(address indexed to, uint256 amount);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event MintDestinationSet(address indexed destination, bool approved);

    constructor(address admin) ERC20("Leveraged BTC", "lvBTC") {
        _setupRole(ADMIN_ROLE, admin);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
    }

    // ... [standard ERC20 functions]

    /**
     * @dev Set approved mint destination.
     * Can only be called by an admin.
     */
    function setMintDestination(address destination, bool approved) external onlyRole(ADMIN_ROLE) {
        _approvedMintDestinations[destination] = approved;
        emit MintDestinationSet(destination, approved);
    }

    /**
     * @dev Add a new minter address.
     * Can only be called by an admin.
     */
    function setMinter(address minter) external onlyRole(ADMIN_ROLE) {
        grantRole(MINTER_ROLE, minter);
        emit MinterAdded(minter);
    }

    /**
     * @dev Remove an existing minter address.
     * Can only be called by an admin.
     */
    function removeMinter(address minter) external onlyRole(ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, minter);
        emit MinterRemoved(minter);
    }

    /**
     * @dev Mints `amount` tokens to an approved destination address.
     * Can only be called by addresses with the minter role.
     * Emits a `Minted` event.
     */
    function mint(uint256 amount, address to) external onlyRole(MINTER_ROLE) {
        require(_approvedMintDestinations[to], "lvBTC: Destination not approved for minting");
        // Logic: Mint the specified amount to the given address.
        emit Minted(to, amount);
    }

    // ... [burn function and other functionalities]

    // Check functions
    function isApprovedMintDestination(address destination) public view returns (bool) {
        return _approvedMintDestinations[destination];
    }
}
