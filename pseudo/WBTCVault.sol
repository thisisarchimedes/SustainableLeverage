pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract WBTCVault is AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    // Define roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");


    // Assuming that WBTC and lvBTC are ERC20 tokens, we'll need their interfaces to interact with them
    IERC20 internal wbtc;
    IERC20 internal lvbtc;

    // Define events  
    event SwappedlvBTCforWBTC(uint256 lvBTCAmount, uint256 WBTCReceived);
    event SwappedWBTCforlvBTC(uint256 WBTCAmount, uint256 lvBTCReceived);
    event LeverageEngineQuotaSet(address indexed leverageEngine, uint256 newQuota);
    event WBTCBorrowed(address indexed leverageEngine, uint256 amount);
    event WBTCRepaid(address indexed leverageEngine, uint256 amount);

    constructor(address admin, address minter, address _wbtc, address _lvbtc) {
        _setupRole(ADMIN_ROLE, admin);
        _setupRole(MINTER_ROLE, minter);
        wbtc = IERC20(_wbtc);
        lvbtc = IERC20(_lvbtc);
    }

    /**
     * @dev Swaps lvBTC held in the vault with WBTC.
     * The WBTC obtained is kept in the WBTC vault contract.
     * This function will require an integration with Curve or a similar protocol
     * to facilitate the swap.
     */
    function swaplvBTCwithWBTC(uint256 amount, uint256 minAmountReceived) external onlyRole(MINTER_ROLE) {
        // 1. Transfer the specified lvBTC amount from the vault to the Curve pool
        // 2. Perform the swap on the Curve pool
        // 3. Ensure that the obtained WBTC amount is transferred back to this vault
        // 4. Check that the WBTC amount received is >= minAmountReceived, else revert
        // 5. Update any internal accounting if necessary
        // 6. Emit an event for the swap

        // Emit event after successful swap
        emit SwappedlvBTCforWBTC(amountIn,  amountOut);
    }

    /**
     * @dev Swaps WBTC held in the vault with lvBTC.
     * The obtained lvBTC is then burned.
     * This function will require an integration with Curve or a similar protocol.
     */
    function swapWBTCwithlvBTC(uint256 amount, uint256 minAmountReceived) external onlyRole(MINTER_ROLE) {
        // 1. Transfer the specified WBTC amount from the vault to the Curve pool
        // 2. Perform the swap on the Curve pool
        // 3. Ensure that the obtained lvBTC amount is transferred back to this vault
        // 4. Check that the lvBTC amount received is >= minAmountReceived, else revert
        // 5. Burn the obtained lvBTC
        // 6. Update any internal accounting if necessary
        // 7. Emit an event for the swap and burn

        // Emit event after successful swap and burn
        emit SwappedWBTCforlvBTC(amountIn, amountOut);
 
    }

    /**
     * @dev Sets the WBTC quota for a specific LeverageEngine.
     * Can only be called by an admin.
     */
    function setLeverageEngineQuota(address leverageEngine, uint256 WBTCQuota) external onlyRole(ADMIN_ROLE) {
        leverageEngineWBTCQuota[leverageEngine] = WBTCQuota;
        emit LeverageEngineQuotaSet(leverageEngine, WBTCQuota);
    }

    /**
    * @dev Allows a LeverageEngine to borrow WBTC from the vault.
    * Verifies that the requested amount is below the LeverageEngine's quota.
    * Sends WBTC to the LeverageEngine and updates the quota.
    */
    function borrowWBTC(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(leverageEngineWBTCQuota[msg.sender] >= amount, "Exceeds available quota");
        
        // Update the quota
        leverageEngineWBTCQuota[msg.sender] = leverageEngineWBTCQuota[msg.sender].sub(amount);
        
        // Transfer WBTC to the LeverageEngine
        require(wbtc.transfer(msg.sender, amount), "WBTC transfer failed");
        
        emit WBTCBorrowed(msg.sender, amount);
    }

    /**
    * @dev Allows a LeverageEngine to repay WBTC to the vault.
    * The quota doesn't increase after repayment.
    */
    function repayWBTC(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        // Transfer WBTC from the LeverageEngine to the vault
        require(wbtc.safeTransferFrom(msg.sender, address(this), amount), "WBTC repayment failed");

        // qouta doesn't go back up on repay - it needs to happen manually 

        emit WBTCRepaid(msg.sender, amount);
    }
}
