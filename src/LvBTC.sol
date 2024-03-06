pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract LVBTC is ERC20, ERC20Burnable, Ownable {
    uint8 private constant DECIMALS = 8;

    constructor(address admin) ERC20("Leveraged BTC", "lvBTC") Ownable(admin) { }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
