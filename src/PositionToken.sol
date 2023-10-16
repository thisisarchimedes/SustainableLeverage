// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { ERC721A } from "ERC721A/ERC721A.sol";

contract PositionToken is ERC721A {
    constructor() ERC721A("PositionToken", "PT") { }

    // TODO - add access control
    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextTokenId();
        _safeMint(to, 1);
    }

    // TODO - add access control
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}
