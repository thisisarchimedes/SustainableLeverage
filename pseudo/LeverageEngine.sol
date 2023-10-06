pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./PositionLedgerLib.sol";

/// @title LeverageEngine Contract
/// @notice This contract facilitates the management of strategy configurations and admin parameters for the Leverage Engine.
/// @notice Leverage Engine is upgradable
contract LeverageEngine is AccessControl {
    using SafeMath for uint256;
    using PositionLedgerLib for PositionLedgerLib.LedgerStorage;

    // Define roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");

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
    uint256 internal liquidationFee;  // Fee taken after returning all debt during liquidation
    uint256 internal exitFee;         // Fee (taken from profits) taken after returning all debt during exit by user
    address internal feeCollector;    // Address that collects fees
    address internal leverageDepositor; // Address of the Leverage Depositor contract

    // Events
    event StrategyConfigUpdated(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event GlobalParameterUpdated(string parameter, uint256 value);
    event FeeCollectorUpdated(address newFeeCollector);

    PositionLedgerLib.LedgerStorage internal ledger;

    ///////////// Admin functions /////////////

    /// @notice Set the configuration for a specific strategy.
    /// @dev Validates the relationship between MM and LB before setting the config.
    /// @param strategy The address of the strategy to configure.
    /// @param _quota The WBTC quota for the strategy.
    /// @param _positionLifetime The lifetime of positions in blocks.
    /// @param _maximumMultiplier The maximum borrowing power multiplier.
    /// @param _liquidationBuffer The threshold for liquidation.
    function setStrategyConfig(
        address strategy,
        uint256 _quota,
        uint256 _positionLifetime,
        uint256 _maximumMultiplier,
        uint256 _liquidationBuffer
    ) external onlyRole(ADMIN_ROLE) {
        // Validate MM and LB relationship
        require(_maximumMultiplier < (1 / (_liquidationBuffer - 1)), "Invalid MM or LB value");

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

    /// @notice Set the global leverage depositor address (for swaping between WBTC and underlying asset).
    /// @param depositor The new leverage depositor address.
    function setFeeCollector(address collector) external onlyRole(ADMIN_ROLE) {
       
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
        uint256 swapRoute
    ) external {
        // Check if strategy is whitelisted and has non-zero quota
        require(strategies[strategy].quota > 0, "Invalid strategy");

        // Check Maximum Multiplier condition
        require(collateralAmount.mul(strategies[strategy].maximumMultiplier) >= wbtcToBorrow, "Borrow exceeds maximum multiplier");

        // Transfer collateral and borrowed WBTC to LeverageEngine
        wbtc.safeTransferFrom(msg.sender, address(this), collateralAmount);
        // Assuming WBTC Vault has a function borrow that lets you borrow WBTC.
        // This function might be different based on actual implementation.
        wbtcVault.borrow(wbtcToBorrow);


        // Deposit borrowed WBTC to LeverageDepositor->strategy and get back shares
        uint256 sharesReceived = leverageDepositor.deposit(wbtcToBorrow);
        require(sharesReceived >= minStrategyShares, "Received less shares than expected");

        // Update Ledger
        PositionLedgerLib.LedgerEntry memory newEntry;
        newEntry.collateralAmount = collateralAmount;
        newEntry.strategyType = strategy;
        newEntry.strategyShares = sharesReceived;
        newEntry.wbtcDebtAmount = wbtcToBorrow;
        newEntry.positionExpirationBlock = block.number + strategies[strategy].positionLifetime;
        newEntry.liquidationBuffer = strategies[strategy].liquidationBuffer;
        newEntry.state = PositionLedgerLib.PositionState.LIVE;
        uint256 nftID = nft.mint(msg.sender);  // Mint NFT and send to user
        ledger.setLedgerEntry(nftID, newEntry);

        // update strategy qouta - reduce by the amount of borrowed WBTC

        // Send nft to user

        // emit event
    }

    /// @notice Allows a user to close their leverage position.
    /// @param nftID The ID of the NFT representing the position.
    /// @param minWBTC Minimum amount of WBTC expected after position closure.
    /// @param swapRoute Route to be used for swapping (sent to leverageDepositor).
    function closePosition(uint256 nftID, uint256 minWBTC, uint256 swapRoute) external {
        // Check if the user owns the NFT
        require(nft.ownerOf(nftID) == msg.sender, "Not the owner of the NFT");

        PositionLedgerLib.LedgerEntry memory position = ledger.entries[nftID];
        
        // Check if the NFT state is LIVE
        require(position.state == PositionLedgerLib.PositionState.LIVE, "Position is not in LIVE state");

        // Unwind the position
        uint256 wbtcReceived = position.strategyType.redeem(position.strategyShares);

        // Repay WBTC debt
        require(wbtcReceived >= position.wbtcDebtAmount, "Not enough WBTC to repay debt");

        // Return WBTC debt to WBTC vault
        wbtcVault.repay(position.wbtcDebtAmount);

        // Deduct the exit fee
        uint256 exitFeeAmount = wbtcReceived.sub(position.wbtcDebtAmount).mul(exitFee).div(100);
        wbtc.transfer(feeCollector, exitFeeAmount);

        // Send the rest of WBTC to the user
        uint256 wbtcLeft = wbtcReceived.sub(position.wbtcDebtAmount).sub(exitFeeAmount);
        require(wbtcLeft >= minWBTC, "Not enough WBTC left after exit fee");
        wbtc.transfer(msg.sender, wbtcLeft);

        // Update the ledger
        position.state = PositionLedgerLib.PositionState.CLOSED;
        ledger.setLedgerEntry(nftID, position);

        // Burn the NFT
        nft.burn(nftID);

        // emit event
    }

    ///////////// Monitor functions /////////////

    /// @notice Expires an array of positions in bulk.
    /// @param nftIDs An array of NFT IDs representing positions to expire.
    /// @param minWBTC Minimum amount of WBTC expected to get back before debt repayment.
    /// @param strategy The strategy associated with the positions.
    function expirePositions(uint256[] memory nftIDs, uint256 minWBTC, address strategy, uint256 swapRoute) external onlyRole(MONITOR_ROLE) {
        uint256 totalShares = 0;
        uint256 totalDebt = 0;
        uint256 totalCollateral = 0;

        // Prep: Iterate over all NFT IDs to aggregate data
        for (uint256 i = 0; i < nftIDs.length; i++) {
            PositionLedgerLib.LedgerEntry memory position = ledger.getLedgerEntry(nftIDs[i]);
            require(position.state == PositionLedgerLib.PositionState.LIVE, "Position not LIVE or already processed");
            require(block.number >= position.positionExpirationBlock, "Position not expired");
            require(position.strategyType == strategy, "Position does not belong to the strategy");

            totalShares = totalShares.add(position.strategyShares);
            totalDebt = totalDebt.add(position.wbtcDebtAmount);
            totalCollateral = totalCollateral.add(position.collateralAmount);
        }

        // Close position: Redeem all shares from the strategy
        uint256 wbtcReceived = strategy.redeem(totalShares);
        require(wbtcReceived >= totalDebt, "Not enough WBTC to repay debt");

        // Repay debt to WBTC Vault
        wbtcVault.repay(totalDebt);

        uint256 wbtcLeft = wbtcReceived.sub(totalDebt);

        // Update the ledger for each position
        for (uint256 i = 0; i < nftIDs.length; i++) {
            PositionLedgerLib.LedgerEntry storage position = ledger.entries[nftIDs[i]];

            // calculating how much WBTC left per position
            uint256 claimableAmount = (wbtcLeft.sub(totalCollateral)).mul(position.strategyShares).div(totalShares).add(position.collateralAmount);

            position.state = PositionLedgerLib.PositionState.EXPIRED;
            position.claimable = claimableAmount;
            position.wbtcDebtAmount = 0;
            position.collateralAmount = 0;
            position.strategyShares = 0;

            ledger.setLedgerEntry(nftIDs[i], position);
        }

        // Move all WBTC to Expired Vault
        wbtc.transfer(expiredVault, wbtcLeft);

        emit PositionsExpired(nftIDs);
    }

    /// @notice Liquidates a position if it's eligible for liquidation.
    /// @param nftID The ID of the NFT representing the position.
    function liquidatePosition(uint256 nftID,  uint256 swapRoute) external onlyRole(MONITOR_ROLE) {
        PositionLedgerLib.LedgerEntry memory position = ledger.getLedgerEntry(nftID);
        
        // Verify the position is LIVE
        require(position.state == PositionLedgerLib.PositionState.LIVE, "Position is not in LIVE state");

        // Redeem the shares for WBTC
        uint256 wbtcReceived = position.strategyType.redeem(position.strategyShares);

        // Verify eligibility
        uint256 threshold = position.wbtcDebtAmount.mul(position.liquidationBuffer);
        require(wbtcReceived < threshold, "Position is not eligible for liquidation");

        // Pay back debts
        if (wbtcReceived < position.wbtcDebtAmount) {
            wbtcVault.repay(wbtcReceived);
            position.state = PositionLedgerLib.PositionState.LIQUIDATED;
            position.claimable = 0;
        } else {
            uint256 wbtcLeft = wbtcReceived.sub(position.wbtcDebtAmount);
            wbtcVault.repay(position.wbtcDebtAmount);

            // Take liquidation fee
            uint256 liquidationFeeAmount = wbtcLeft.mul(liquidationFee).div(100);
            wbtc.transfer(feeCollector, liquidationFeeAmount);

            // Send remaining WBTC to ExpiredVault
            uint256 remainingWBTC = wbtcLeft.sub(liquidationFeeAmount);
            wbtc.transfer(expiredVault, remainingWBTC);

            // Update the ledger
            position.state = PositionLedgerLib.PositionState.LIQUIDATED;
            position.claimable = remainingWBTC;
        }

        ledger.setLedgerEntry(nftID, position);
    }


    ///////////// View functions /////////////

    /// @notice Preview the number of strategy shares expected from opening a position.
    /// @param collateralAmount Amount of WBTC the user is planning to deposit as collateral.
    /// @param wbtcToBorrow Amount of WBTC the user is planning to borrow.
    /// @param strategy The strategy user is considering.
    /// @return estimatedShares The estimated number of strategy shares the user will receive.
    function previewOpenPosition(
        uint256 collateralAmount, 
        uint256 wbtcToBorrow, 
        address strategy
    ) external view returns (uint256 estimatedShares) {
        // Check if strategy is whitelisted and has non-zero quota
        require(strategies[strategy].quota > 0, "Invalid strategy");

        // Check Maximum Multiplier condition
        require(collateralAmount.mul(strategies[strategy].maximumMultiplier) >= wbtcToBorrow, "Borrow exceeds maximum multiplier");

        // Here, we make an assumption that the strategy has a function to give us an estimate of the shares
        //estimatedShares = strategy.previewDeposit(collateralAmount.add(wbtcToBorrow));
    }

    /// @notice Preview the amount of WBTC expected from closing a position.
    /// @param nftID The ID of the NFT representing the position to close.
    /// @return estimatedWBTC The estimated amount of WBTC the user will receive after all deductions.
    function previewClosePosition(uint256 nftID) external view returns (uint256 estimatedWBTC) {
        PositionLedgerLib.LedgerEntry memory position = ledger.entries[nftID];

        // Estimate the amount of WBTC to receive from redeeming the strategy shares
        uint256 wbtcFromShares = position.strategyType.previewRedeem(position.strategyShares);

        // Estimate the WBTC left after repaying debt
        uint256 wbtcAfterDebt = wbtcFromShares > position.wbtcDebtAmount ? wbtcFromShares.sub(position.wbtcDebtAmount) : 0;

        // Deduct the estimated exit fee
        uint256 exitFeeAmount = wbtcAfterDebt.mul(exitFee).div(100);

        // Calculate the estimated WBTC amount left after deducting the exit fee
        estimatedWBTC = wbtcAfterDebt.sub(exitFeeAmount);
    }

    /// @notice Preview the total amount of WBTC expected from expiring positions.
    /// @param nftIDs An array of NFT IDs representing the positions to check.
    /// @param strategy The strategy associated with these positions.
    /// @return estimatedWBTC The estimated total amount of WBTC before repaying the debt.
    function previewExpirePosition(uint256[] memory nftIDs, address strategy) external view returns (uint256 estimatedWBTC) {
        uint256 totalShares = 0;

        // Iterate over all NFT IDs to aggregate the total shares
        for (uint256 i = 0; i < nftIDs.length; i++) {
            PositionLedgerLib.LedgerEntry memory position = ledger.getLedgerEntry(nftIDs[i]);

            // Verify each position
            require(position.state == PositionLedgerLib.PositionState.LIVE, "Position not LIVE or already processed");
            require(block.number >= position.positionExpirationBlock, "Position not expired");
            require(position.strategyType == strategy, "Position does not belong to the strategy");

            totalShares = totalShares.add(position.strategyShares);
        }

        // Here, we assume the strategy has a function to give us an estimate of the WBTC for the shares
        estimatedWBTC = strategy.previewRedeem(totalShares);
    }

    /// @notice Checks if a position is eligible for liquidation.
    /// @param nftID The ID of the NFT representing the position.
    /// @return TRUE if the position is eligible for liquidation, FALSE otherwise.
    function previewIsLiquidatable(uint256 nftID) external view returns (bool) {
        PositionLedgerLib.LedgerEntry memory position = ledger.getLedgerEntry(nftID);
        
        // Ensure the position is LIVE
        if (position.state != PositionLedgerLib.PositionState.LIVE) {
            return false;
        }

        // Simulate redeeming the shares for WBTC
        // Note: This might require a "preview" function on the strategy to provide a close estimate.
        uint256 estimatedWBTC = position.strategyType.previewRedeem(position.strategyShares);

        // Check eligibility
        uint256 threshold = position.wbtcDebtAmount.mul(position.liquidationBuffer);
        return estimatedWBTC < threshold;
    }


    /// @notice Get the configuration for a specific strategy.
    /// @param strategy The address of the strategy to retrieve configuration for.
    /// @return The strategy configuration.
    function getStrategyConfig(address strategy) external view returns (StrategyConfig memory) {
        return strategies[strategy];
    }

    /// @notice Get the global liquidation fee.
    /// @return The global liquidation fee.
    function getLiquidationFee() external view returns (uint256) {
        return liquidationFee;
    }

    /// @notice Get the global exit fee.
    /// @return The global exit fee.
    function getExitFee() external view returns (uint256) {
        return exitFee;
    }

    /// @notice Get the global fee collector address.
    /// @return The address of the fee collector.
    function getFeeCollector() external view returns (address) {
        return feeCollector;
    }
}
