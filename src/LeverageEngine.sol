// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import "openzeppelin-contracts/access/AccessControl.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "./PositionLedgerLib.sol";
import { IWBTCVault } from "./interfaces/IWBTCVault.sol";
import { ILeverageDepositor } from "./interfaces/ILeverageDepositor.sol";
import { PositionToken } from "./PositionToken.sol";
import { console2 } from "forge-std/console2.sol";
/// @title LeverageEngine Contract
/// @notice This contract facilitates the management of strategy configurations and admin parameters for the Leverage
/// Engine.
/// @notice Leverage Engine is upgradable

contract LeverageEngine is AccessControl {
    using PositionLedgerLib for PositionLedgerLib.LedgerStorage;
    using SafeERC20 for IERC20;

    // Define roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");

    // WBTC token
    IERC20 immutable wbtc;

    // WBTC Vault
    IWBTCVault public wbtcVault;

    // Position NFT
    PositionToken public nft;

    // Leverage Depositor
    ILeverageDepositor public leverageDepositor;

    /// @notice Strategy configurations structure
    /// @param quota WBTC Quota for the strategy
    /// @param positionLifetime Lifetime of a position in blocks
    /// @param maximumMultiplier Maximum borrowing power multiplier
    /// @param liquidationBuffer Threshold for liquidation
    struct StrategyConfig {
        uint256 quota;
        uint256 positionLifetime;
        uint256 maximumMultiplier;
        uint256 liquidationBuffer;
    }

    // Mapping of strategies to their configurations
    mapping(address => StrategyConfig) internal strategies;

    // Global admin parameters
    uint256 public liquidationFee; // Fee taken after returning all debt during liquidation
    uint256 public exitFee; // Fee (taken from profits) taken after returning all debt during exit by user
    address public feeCollector; // Address that collects fees

    //Errors
    error ExceedBorrowLimit();
    error LessThanMinimumShares();
    // Events

    event StrategyConfigUpdated(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event GlobalParameterUpdated(string parameter, uint256 value);
    event FeeCollectorUpdated(address newFeeCollector);
    event PositionOpened(
        uint256 indexed nftID,
        address indexed user,
        address indexed strategy,
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        uint256 positionExpireBlock
    );

    PositionLedgerLib.LedgerStorage internal ledger;

    constructor(IWBTCVault _wbtcVault, ILeverageDepositor _leverageDepositor, PositionToken _nft) {
        wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        wbtcVault = _wbtcVault;
        leverageDepositor = _leverageDepositor;
        nft = _nft;
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    ///////////// Admin functions /////////////

    /// @notice Set the configuration for a specific strategy.
    /// @dev Validates the relationship between MM and LB before setting the config.
    /// @param strategy The address of the strategy to configure.
    /// @param _quota The WBTC quota for the strategy.
    /// @param _positionLifetime The lifetime of positions in blocks.
    /// @param _maximumMultiplier The maximum borrowing power multiplier. in 1e8.
    /// @param _liquidationBuffer The threshold for liquidation. in 1e8
    function setStrategyConfig(
        address strategy,
        uint256 _quota,
        uint256 _positionLifetime,
        uint256 _maximumMultiplier,
        uint256 _liquidationBuffer
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        // Validate MM and LB relationship
        require(_maximumMultiplier < (1e16 / (_liquidationBuffer - 1e8)), "Invalid MM or LB value");

        strategies[strategy] = StrategyConfig({
            quota: _quota,
            positionLifetime: _positionLifetime,
            maximumMultiplier: _maximumMultiplier,
            liquidationBuffer: _liquidationBuffer
        });

        emit StrategyConfigUpdated(strategy);
    }

    /// @notice Removes a strategy from the LeverageEngine.
    /// @dev This function sets the strategy's quota to 0 and resets its parameters.
    /// @param strategy The address of the strategy to remove.
    function removeStrategy(address strategy) external onlyRole(ADMIN_ROLE) {
        require(strategies[strategy].quota > 0, "Strategy not active");

        strategies[strategy].quota = 0;
        strategies[strategy].positionLifetime = 0;
        strategies[strategy].maximumMultiplier = 0;
        strategies[strategy].liquidationBuffer = 0;

        emit StrategyRemoved(strategy);
    }

    /// @notice Set the position lifetime for a specific strategy.
    /// @param strategy The address of the strategy to configure.
    /// @param numberOfBlocksToLive The new lifetime of positions in blocks.
    function setPositionLifetime(address strategy, uint256 numberOfBlocksToLive) external onlyRole(ADMIN_ROLE) {
        strategies[strategy].positionLifetime = numberOfBlocksToLive;
        emit StrategyConfigUpdated(strategy);
    }

    /// @notice Set the maximum multiplier for a specific strategy.
    /// @param strategy The address of the strategy to configure.
    /// @param value The new maximum multiplier value.
    function setMaximumMultiplier(address strategy, uint256 value) external onlyRole(ADMIN_ROLE) {
        strategies[strategy].maximumMultiplier = value;
        emit StrategyConfigUpdated(strategy);
    }

    /// @notice Set the liquidation buffer for a specific strategy.
    /// @param strategy The address of the strategy to configure.
    /// @param value The new liquidation buffer value.
    function setLiquidationBuffer(address strategy, uint256 value) external onlyRole(ADMIN_ROLE) {
        strategies[strategy].liquidationBuffer = value;
        emit StrategyConfigUpdated(strategy);
    }

    /// @notice Set the global liquidation fee.
    /// @param fee The new liquidation fee percentage.
    function setLiquidationFee(uint256 fee) external onlyRole(ADMIN_ROLE) {
        liquidationFee = fee;
        emit GlobalParameterUpdated("LiquidationFee", fee);
    }

    /// @notice Set the global exit fee.
    /// @param fee The new exit fee percentage.
    function setExitFee(uint256 fee) external onlyRole(ADMIN_ROLE) {
        exitFee = fee;
        emit GlobalParameterUpdated("ExitFee", fee);
    }

    /// @notice Set the global fee collector address.
    /// @param collector The new fee collector address.
    function setFeeCollector(address collector) external onlyRole(ADMIN_ROLE) {
        feeCollector = collector;
        emit FeeCollectorUpdated(collector);
    }

    ///////////// User functions /////////////

    /// @notice Allows a user to open a leverage position.
    /// @param collateralAmount Amount of WBTC to be deposited as collateral.
    /// @param wbtcToBorrow Amount of WBTC to borrow.
    /// @param strategy Strategy to be used for leveraging.
    /// @param minStrategyShares Minimum amount of strategy shares expected in return.
    /// @param swapRoute Route to be used for swapping (sent to leverageDepositor).
    function openPosition(
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        address strategy,
        uint256 minStrategyShares,
        ILeverageDepositor.SwapRoute swapRoute
    )
        external
    {
        // update strategy qouta - reduce by the amount of borrowed WBTC and it would revert if the strategy has no
        // quota
        strategies[strategy].quota -= wbtcToBorrow;
        // Check Maximum Multiplier condition
        if (collateralAmount * strategies[strategy].maximumMultiplier / 1e8 < wbtcToBorrow) revert ExceedBorrowLimit();
        // Transfer collateral and borrowed WBTC to LeverageEngine
        wbtc.safeTransferFrom(msg.sender, address(this), collateralAmount);
        // Assuming WBTC Vault has a function borrow that lets you borrow WBTC.
        // This function might be different based on actual implementation.
        wbtcVault.borrow(wbtcToBorrow);

        // Deposit borrowed WBTC to LeverageDepositor->strategy and get back shares
        uint256 sharesReceived = leverageDepositor.deposit(strategy, swapRoute, collateralAmount + wbtcToBorrow);
        if (sharesReceived < minStrategyShares) revert LessThanMinimumShares();

        // Update Ledger
        PositionLedgerLib.LedgerEntry memory newEntry;
        newEntry.collateralAmount = collateralAmount;
        newEntry.strategyType = strategy;
        newEntry.strategyShares = sharesReceived;
        newEntry.wbtcDebtAmount = wbtcToBorrow;
        newEntry.positionExpirationBlock = block.number + strategies[strategy].positionLifetime;
        newEntry.liquidationBuffer = strategies[strategy].liquidationBuffer;
        newEntry.state = PositionLedgerLib.PositionState.LIVE;
        uint256 nftID = nft.mint(msg.sender); // Mint NFT and send to user
        ledger.setLedgerEntry(nftID, newEntry);

        // emit event
        emit PositionOpened(
            nftID, msg.sender, strategy, collateralAmount, wbtcToBorrow, newEntry.positionExpirationBlock
        );
    }

    ///////////// View functions /////////////

    /// @notice Preview the number of AMM LP tokensexpected from opening a position.
    /// @param collateralAmount Amount of WBTC the user is planning to deposit as collateral.
    /// @param wbtcToBorrow Amount of WBTC the user is planning to borrow.
    /// @param strategy The strategy user is considering.
    /// @return estimatedShares The estimated number of AMM LP tokens s the user will receive.
    function previewOpenPosition(
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        address strategy
    )
        external
        view
        returns (uint256 estimatedShares)
    {
        // Check if strategy is whitelisted and has non-zero quota
        require(strategies[strategy].quota > 0, "Invalid strategy");

        // Check Maximum Multiplier condition
        if (collateralAmount * strategies[strategy].maximumMultiplier / 1e8 < wbtcToBorrow) revert ExceedBorrowLimit();

        // Here, we make an assumption that the strategy has a function to give us an estimate of the shares
        //estimatedShares = leverageDepositor.previewDeposit(collateralAmount.add(wbtcToBorrow));
    }

    /// @notice Get the configuration for a specific strategy.
    /// @param strategy The address of the strategy to retrieve configuration for.
    /// @return The strategy configuration.
    function getStrategyConfig(address strategy) external view returns (StrategyConfig memory) {
        return strategies[strategy];
    }

    function getPosition(uint256 nftID) external view returns (PositionLedgerLib.LedgerEntry memory) {
        return ledger.getLedgerEntry(nftID);
    }
}
