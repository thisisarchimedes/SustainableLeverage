pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { AccessControl } from "openzeppelin-contracts/access/AccessControl.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";

contract LVBTC is ERC20Burnable, AccessControl {
    uint8 private constant DECIMALS = 8;
    address private mintDestination;

    mapping(address => bool) public minters;

    constructor(address admin) ERC20("Leveraged BTC", "lvBTC") {
        _grantRole(ProtocolRoles.ADMIN_ROLE, admin);
        _grantRole(ProtocolRoles.MINTER_ROLE, admin);
        _setRoleAdmin(ProtocolRoles.ADMIN_ROLE, ProtocolRoles.ADMIN_ROLE);
        _setRoleAdmin(ProtocolRoles.MINTER_ROLE, ProtocolRoles.ADMIN_ROLE);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function mint(uint256 amount) public onlyRole(ProtocolRoles.MINTER_ROLE) {
        _mint(mintDestination, amount);
    }

    function setMintDestination(address to) public onlyRole(ProtocolRoles.ADMIN_ROLE) {
        mintDestination = to;
    }

    function addMinter(address minter) public onlyRole(ProtocolRoles.ADMIN_ROLE) {
        minters[minter] = true;
        grantRole(ProtocolRoles.MINTER_ROLE, minter);
    }

    function removeMinter(address minter) public onlyRole(ProtocolRoles.ADMIN_ROLE) {
        revokeRole(ProtocolRoles.MINTER_ROLE, minter);
    }
}
