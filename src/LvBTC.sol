// pragma solidity ^0.8.18;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/Extensions/ERC20Burnable.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";

// contract lvBTC is ERC20, AccessControl, ERC20Burnable {
//     uint256 private constant DECIMALS = 8;

//     constructor(address admin) ERC20("Leveraged BTC", "lvBTC") {
//         _setupRole(ADMIN_ROLE, admin);
//         _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
//     }

//     function decimals() public override returns (uint256) {
//         return DECIMALS;
//     }

//     function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
//         _mint(to, amount);
//     }
// }

// /*

// [] Pool is low on WBTC:
//     [] Send WBTC from the vault to the pool (swap WBTC>>lvBTC)
//     [] Burn the lvBTC we got for the WBTC
// [] Get WBTC from the pool to the vault:
//     [] Mint lvBTC and send it to the vault
//     [] Swap lvBTC>>WBTC

// */
