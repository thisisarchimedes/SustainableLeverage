// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { AccessControl } from "openzeppelin-contracts/access/AccessControl.sol";

import { ERC721 } from "openzeppelin-contracts/token/ERC721/ERC721.sol";

import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";

contract PositionToken is ERC721, AccessControl {
    using ProtocolRoles for *;

    string internal _name = "PositionToken";
    string internal _symbol = "PT";
    string internal _tokenURI = "";
    uint256 internal nextTokenId = 0;

    constructor() ERC721("PositionToken", "PT") {
        _setRoleAdmin(ProtocolRoles.ADMIN_ROLE, ProtocolRoles.ADMIN_ROLE);
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionOpener);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.positionCloser);
        _grantRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE, dependencies.expiredVault);
    }

    function setTokenURI(string memory uri) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        _tokenURI = uri;
    }

    function mint(address to) external onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE) returns (uint256) {
        uint256 tokenId = nextTokenId;
        _mint(to, tokenId);
        nextTokenId += 1;

        return tokenId;
    }

    function burn(uint256 tokenId) external onlyRole(ProtocolRoles.INTERNAL_CONTRACT_ROLE) {
        _burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return interfaceId == type(ERC721).interfaceId;
    }
}
