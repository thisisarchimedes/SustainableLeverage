// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title PositionToken Contract
/// @dev Represents a user's leveraged position as an NFT.
contract PositionToken is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;

    // Counter for NFT IDs
    Counters.Counter private _tokenIdCounter;

    // Base URI for token metadata. It could be IPFS or another decentralized storage URL.
    string private _baseTokenURI;

    constructor(string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) {
        _baseTokenURI = baseURI;
    }

    /// @notice Mints a new PositionToken NFT and sends it to the user.
    /// @dev The ID of the minted token is returned for tying it to the ledger.
    /// @param to Address of the user receiving the NFT.
    /// @return The ID of the minted token.
    function mint(address to) external onlyOwner returns (uint256) {
        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();
        _safeMint(to, newTokenId);
        return newTokenId;
    }

    /// @notice Burns an NFT.
    /// @dev Represents the closure of a position.
    /// @param tokenId ID of the NFT to burn.
    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner of this token");
        _burn(tokenId);
    }

    /// @notice Updates the base URI for the NFT metadata.
    /// @param baseURI New base URI.
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}
