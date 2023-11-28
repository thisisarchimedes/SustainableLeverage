// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import { console2 } from "forge-std/console2.sol";
import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "./PositionLedgerLib.sol";
import "./interfaces/ILeverageEngine.sol";
import "./interfaces/IERC20Detailed.sol";
import { IWBTCVault } from "./interfaces/IWBTCVault.sol";
import { IExpiredVault } from "./interfaces/IExpiredVault.sol";
import { ILeverageDepositor } from "./interfaces/ILeverageDepositor.sol";
import { IOracle } from "./interfaces/IOracle.sol";
import { PositionToken } from "./PositionToken.sol";
import { SwapAdapter } from "./SwapAdapter.sol";
import { IMultiPoolStrategy } from "./interfaces/IMultiPoolStrategy.sol";
import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";
import { Roles } from "./libs/roles.sol";

/// @title LeverageEngine Contract
/// @notice This contract facilitates the management of strategy configurations and admin parameters for the Leverage
/// Engine.
/// @notice Leverage Engine is upgradable

contract LeverageEngine is ILeverageEngine, AccessControlUpgradeable {
    using PositionLedgerLib for PositionLedgerLib.LedgerStorage;
    using SafeERC20 for IERC20;
    using Roles for *;

    uint256 internal constant BASE_DENOMINATOR = 10_000;
    uint8 internal constant WBTC_DECIMALS = 8;

    address public monitor;

    IERC20 public wbtc;
    IWBTCVault internal wbtcVault;

    PositionToken public nft;
    ILeverageDepositor internal leverageDepositor;
    SwapAdapter internal swapAdapter;

    address public expiredVault;

    mapping(address => StrategyConfig) internal strategies;

    /// Mapping of oracles token => oracle
    mapping(address => IOracle) public oracles;

    // Global admin parameters
    uint256 public exitFee; // Fee (taken from profits) taken after returning all debt during exit by user in 10000
    address public feeCollector; // Address that collects fees in 10000

    PositionLedgerLib.LedgerStorage internal ledger;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _wbtcVault,
        address _leverageDepositor,
        address _nft,
        address _swapAdapter,
        address _feeCollector
    )
        external
        initializer
    {
        __AccessControl_init();
        _grantRole(Roles.ADMIN_ROLE, msg.sender);
        wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        wbtcVault = IWBTCVault(_wbtcVault);
        wbtc.approve(_wbtcVault, type(uint256).max);
        leverageDepositor = ILeverageDepositor(_leverageDepositor);
        nft = PositionToken(_nft);
        swapAdapter = SwapAdapter(_swapAdapter);
        exitFee = 50;
        feeCollector = _feeCollector;
    }

    ///////////// Admin functions /////////////

    /// @notice Set the configuration for a specific strategy.
    /// @dev Validates the relationship between MM and LB before setting the config.
    /// @param config StrategyConfig structs that holds the config variables
    function setStrategyConfig(address strategy, StrategyConfig calldata config) external onlyRole(Roles.ADMIN_ROLE) {
        // Validate MM and LB relationship
        require(
            config.maximumMultiplier < (1e16 / (config.liquidationBuffer - 10 ** WBTC_DECIMALS)),
            "Invalid MM or LB value"
        );

        strategies[strategy] = config;

        emit StrategyConfigUpdated(
            strategy,
            config.quota,
            config.positionLifetime,
            config.maximumMultiplier,
            config.liquidationBuffer,
            config.liquidationFee
        );
    }

    /// @notice Removes a strategy from the LeverageEngine.
    /// @dev This function sets the strategy's quota to 0 and resets its parameters.
    /// @param strategy The address of the strategy to remove.
    function removeStrategy(address strategy) external onlyRole(Roles.ADMIN_ROLE) {
        require(strategies[strategy].quota > 0, "Strategy not active");

        delete strategies[strategy];

        emit StrategyRemoved(strategy);
    }

    /**
     *  @notice Set the oracle address for a token
     * @param token address of the token
     * @param oracle address of the oracle
     */
    function setOracle(address token, IOracle oracle) external onlyRole(Roles.ADMIN_ROLE) {
        oracles[token] = oracle;
        emit OracleSet(token, oracle);
    }

    /**
     * @notice Change the swap adapter address
     * @param _swapAdapter The address of the new swap adapter.
     */
    function changeSwapAdapter(address _swapAdapter) external onlyRole(Roles.ADMIN_ROLE) {
        swapAdapter = SwapAdapter(_swapAdapter);
    }

    /// @notice Set the global exit fee.
    /// @param fee The new exit fee percentage.
    function setExitFee(uint256 fee) external onlyRole(Roles.ADMIN_ROLE) {
        exitFee = fee;
        emit GlobalParameterUpdated("ExitFee", fee);
    }

    /// @notice Set the global fee collector address.
    /// @param collector The new fee collector address.
    function setFeeCollector(address collector) external onlyRole(Roles.ADMIN_ROLE) {
        feeCollector = collector;
        emit FeeCollectorUpdated(collector);
    }

    /// @notice Set the monitor role.
    /// @param _monitor The new monitor address.
    function setMonitor(address _monitor) external onlyRole(Roles.ADMIN_ROLE) {
        if (monitor != address(0)) {
            _revokeRole(Roles.MONITOR_ROLE, monitor);
        }
        monitor = _monitor;
        _grantRole(Roles.MONITOR_ROLE, _monitor);
        emit MonitorUpdated(_monitor);
    }

    /// @notice Set the expired vault role.
    /// @param _expiredVault The new expired vault address.
    function setExpiredVault(address _expiredVault) external onlyRole(Roles.ADMIN_ROLE) {
        if (expiredVault != address(0)) {
            wbtc.approve(expiredVault, 0);
            _revokeRole(Roles.EXPIRED_VAULT_ROLE, expiredVault);
        }
        expiredVault = _expiredVault;
        _grantRole(Roles.EXPIRED_VAULT_ROLE, _expiredVault);
        wbtc.approve(_expiredVault, type(uint256).max);
        emit ExpiredVaultUpdated(_expiredVault);
    }

    function setLiquidationFee(address strategy, uint256 fee) external onlyRole(Roles.ADMIN_ROLE) {
        strategies[strategy].liquidationFee = fee;

        emit StrategyLiquidationFeeUpdated(strategy, fee);
    }

    ///////////// User functions /////////////

    /// @notice Allows a user to open a leverage position.
    /// @param collateralAmount Amount of WBTC to be deposited as collateral.
    /// @param wbtcToBorrow Amount of WBTC to borrow.
    /// @param strategy Strategy to be used for leveraging.
    /// @param minStrategyShares Minimum amount of strategy shares expected in return.
    /// @param swapRoute Route to be used for swapping
    function openPosition(
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        address strategy,
        uint256 minStrategyShares,
        SwapAdapter.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        external
        returns (uint256 nftId)
    {
        // update strategy qouta - reduce by the amount of borrowed WBTC and it would revert if the strategy has no
        // quota
        strategies[strategy].quota -= wbtcToBorrow;
        // Check Maximum Multiplier condition
        if (collateralAmount * strategies[strategy].maximumMultiplier / 10 ** WBTC_DECIMALS < wbtcToBorrow) {
            revert ExceedBorrowLimit();
        }
        // Transfer collateral and borrowed WBTC to LeverageEngine
        wbtc.safeTransferFrom(msg.sender, address(this), collateralAmount);
        // Assuming WBTC Vault has a function borrow that lets you borrow WBTC.
        // This function might be different based on actual implementation.
        uint256 totalAmount = collateralAmount + wbtcToBorrow;
        wbtcVault.borrow(wbtcToBorrow); //TODO: directly transfer from vault to swapadapter
        wbtc.transfer(address(swapAdapter), totalAmount); // TODO remove that when we implement wbtcvault and transfer
            // directly
        address strategyUnderlyingToken = IMultiPoolStrategy(strategy).asset();
        // Swap borrowed WBTC to strategy token
        uint256 receivedAmount = swapAdapter.swap(
            wbtc,
            IERC20(strategyUnderlyingToken),
            totalAmount,
            exchange,
            swapData,
            swapRoute,
            address(leverageDepositor)
        );
        {
            uint256 receivedTokensInWbtc = _getWBTCValueFromTokenAmount(strategyUnderlyingToken, receivedAmount);
            if (wbtcToBorrow >= receivedTokensInWbtc * strategies[strategy].liquidationBuffer / 10 ** WBTC_DECIMALS) {
                revert NotEnoughTokensReceived();
            }
        }

        // Deposit borrowed WBTC to LeverageDepositor->strategy and get back shares
        uint256 sharesReceived = leverageDepositor.deposit(strategy, strategyUnderlyingToken, receivedAmount);
        if (sharesReceived < minStrategyShares) revert LessThanMinimumShares();
        StrategyConfig memory strategyConfig = strategies[strategy];

        // Update Ledger
        PositionLedgerLib.LedgerEntry memory newEntry;
        newEntry.collateralAmount = collateralAmount;
        newEntry.strategyAddress = strategy;
        newEntry.strategyShares = sharesReceived;
        newEntry.wbtcDebtAmount = wbtcToBorrow;
        newEntry.positionExpirationBlock = block.number + strategyConfig.positionLifetime;
        newEntry.liquidationBuffer = strategyConfig.liquidationBuffer;
        newEntry.state = PositionLedgerLib.PositionState.LIVE;
        nftId = nft.mint(msg.sender); // Mint NFT and send to user
        ledger.setLedgerEntry(nftId, newEntry);

        // emit event
        emit PositionOpened(
            nftId,
            msg.sender,
            newEntry.strategyAddress,
            newEntry.collateralAmount,
            newEntry.wbtcDebtAmount,
            newEntry.positionExpirationBlock,
            sharesReceived,
            strategyConfig.liquidationBuffer
        );
    }

    /// @notice Allows a user to close their leverage position.
    /// @param nftId The ID of the NFT representing the position.
    /// @param minWBTC Minimum amount of WBTC expected after position closure.
    /// @param swapRoute Route to be used for swapping
    /// @param swapData Swap data for the swap adapter
    /// @param exchange Exchange to be used for swapping
    function closePosition(
        uint256 nftId,
        uint256 minWBTC,
        SwapAdapter.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        external
    {
        // Check if the user owns the NFT
        if (nft.ownerOf(nftId) != msg.sender) revert NotOwner();

        PositionLedgerLib.LedgerEntry memory position = ledger.entries[nftId];

        // Check if the NFT state is LIVE
        if (position.state != PositionLedgerLib.PositionState.LIVE) revert PositionNotLive();

        // Unwind the position
        uint256 wbtcReceived = _unwindPosition(position, swapRoute, swapData, exchange);

        // Repay WBTC debt
        if (wbtcReceived < position.wbtcDebtAmount) revert NotEnoughWBTC();

        // Return WBTC debt to WBTC vault
        wbtcVault.repay(nftId, position.wbtcDebtAmount);

        // Deduct the exit fee
        uint256 exitFeeAmount = (wbtcReceived - position.wbtcDebtAmount) * exitFee / BASE_DENOMINATOR;
        wbtc.transfer(feeCollector, exitFeeAmount);

        // Send the rest of WBTC to the user
        uint256 wbtcLeft = wbtcReceived - position.wbtcDebtAmount - exitFeeAmount;
        if (wbtcLeft < minWBTC) revert NotEnoughTokensReceived();
        wbtc.transfer(msg.sender, wbtcLeft);

        // Update the ledger
        position.state = PositionLedgerLib.PositionState.CLOSED;
        ledger.setLedgerEntry(nftId, position);

        // Burn the NFT
        nft.burn(nftId);

        // emit event
        emit PositionClosed(
            nftId, msg.sender, position.strategyAddress, wbtcLeft, position.wbtcDebtAmount, exitFeeAmount
        );
    }

    ///////////// Monitor functions /////////////

    /// @notice Allows the monitor to liquidate a position.
    /// 1. Close position
    ///     * 1.2. Find how many shares belong to this nftID
    ///     * 1.3. call strategy redeem with the amount of shares
    ///     * 1.4. now we get the underlying token (e.g.: ETH) back
    /// * 2. Swap underlying token to WBTC
    /// * 3. Check that the amount of WBTC we have is < debt * liquidationBuffer - if not, revert V
    /// * 4. pay back debt V
    /// * 5. if something left
    ///     * 5.1. take liquidation fee
    ///     * 5.2. send whatever left to expiration vault
    ///
    /// @param nftId The ID of the NFT representing the position.
    /// @param minWBTC Minimum amount of WBTC expected after position closure.
    /// @param swapRoute Route to be used for swapping
    /// @param swapData Swap data for the swap adapter
    /// @param exchange Exchange to be used for swapping
    function liquidatePosition(
        uint256 nftId,
        uint256 minWBTC,
        SwapAdapter.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        external
        onlyRole(Roles.MONITOR_ROLE)
    {
        PositionLedgerLib.LedgerEntry memory position = getPosition(nftId);

        if (position.state != PositionLedgerLib.PositionState.LIVE) revert PositionNotLive();

        uint256 wbtcReceived = _unwindPosition(position, swapRoute, swapData, exchange);

        // Repay WBTC debt
        if (wbtcReceived > position.wbtcDebtAmount * position.liquidationBuffer / (10 ** WBTC_DECIMALS)) {
            revert NotEligibleForLiquidation();
        }

        if (wbtcReceived < minWBTC) revert NotEnoughTokensReceived();

        // Return WBTC debt to WBTC vault
        wbtcVault.repay(nftId, position.wbtcDebtAmount);

        if (wbtcReceived > position.wbtcDebtAmount) {
            uint256 wbtcLeft = wbtcReceived - position.wbtcDebtAmount;
            uint256 liquidationFeeAmount =
                getStrategyConfig(position.strategyAddress).liquidationFee * wbtcLeft / (10 ** WBTC_DECIMALS);
            position.claimableAmount = wbtcLeft - liquidationFeeAmount;

            wbtc.transfer(feeCollector, liquidationFeeAmount);

            IExpiredVault(expiredVault).deposit(position.claimableAmount);
        }

        position.state = PositionLedgerLib.PositionState.LIQUIDATED;

        ledger.setLedgerEntry(nftId, position);
    }

    ///////////// Expired Vault functions /////////////

    /// @notice ExpiredVault will call this function to close an expired position.
    /// @param nftID The ID of the NFT representing the position.
    function closeExpiredOrLiquidatedPosition(uint256 nftID, address sender) external onlyRole(Roles.EXPIRED_VAULT_ROLE) {
        // Check if the user owns the NFT
        if (nft.ownerOf(nftID) != sender) revert NotOwner();

        PositionLedgerLib.LedgerEntry storage position = ledger.entries[nftID];

        // Check if the NFT state is Expired or Liquidated
        if (
            position.state != PositionLedgerLib.PositionState.EXPIRED
                && position.state != PositionLedgerLib.PositionState.LIQUIDATED
        ) revert PositionNotExpiredOrLiquidated();

        // Rememver the received amount for emitting the event
        uint256 receivedAmount = position.claimableAmount;

        // Update the ledger
        position.state = PositionLedgerLib.PositionState.CLOSED;
        position.claimableAmount = 0;

        // Burn the NFT
        nft.burn(nftID);

        // Emit event
        // No exit fee is charged for expired positions
        emit PositionClosed(nftID, sender, position.strategyAddress, receivedAmount, position.wbtcDebtAmount, 0);
    }

    ///////////// View functions /////////////

    /// @notice Preview the number of AMM LP tokensexpected from opening a position.
    /// @param collateralAmount Amount of WBTC the user is planning to deposit as collateral.
    /// @param wbtcToBorrow Amount of WBTC the user is planning to borrow.
    /// @param strategy The strategy user is considering.
    /// @param minimumExpected Minimum amount of tokens expected after swap from WBTC to strategy token.
    /// @return estimatedShares The estimated number of AMM LP tokens s the user will receive.
    function previewOpenPosition(
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        address strategy,
        uint256 minimumExpected
    )
        external
        view
        returns (uint256 estimatedShares)
    {
        if (strategies[strategy].quota < wbtcToBorrow) revert ExceedBorrowQuota();
        // Check Maximum Multiplier condition
        if (collateralAmount * strategies[strategy].maximumMultiplier / 10 ** WBTC_DECIMALS < wbtcToBorrow) {
            revert ExceedBorrowLimit();
        }

        // Here, we make an assumption that the strategy has a function to give us an estimate of the shares
        estimatedShares = IMultiPoolStrategy(strategy).previewDeposit(minimumExpected);
    }

    function isPositionLiquidatable(uint256 nftId) external view returns (bool) {
        PositionLedgerLib.LedgerEntry memory position = getPosition(nftId);

        if (position.state != PositionLedgerLib.PositionState.LIVE) revert PositionNotLive();

        uint256 positionValue = previewPositionValueInWBTC(nftId);

        return positionValue < (position.wbtcDebtAmount * position.liquidationBuffer) / (10 ** WBTC_DECIMALS);
    }

    function previewPositionValueInWBTC(uint256 nftId) public view returns (uint256 positionValueInWBTC) {
        PositionLedgerLib.LedgerEntry memory position = getPosition(nftId);
        uint256 strategyValueTokenEstimatedAmount =
            IMultiPoolStrategy(position.strategyAddress).convertToAssets(position.strategyShares);
        address strategyValueTokenAddress = IMultiPoolStrategy(position.strategyAddress).asset();

        positionValueInWBTC = _getWBTCValueFromTokenAmount(strategyValueTokenAddress, strategyValueTokenEstimatedAmount);
    }

    /// @notice Get the configuration for a specific strategy.
    /// @param strategy The address of the strategy to retrieve configuration for.
    /// @return The strategy configuration.
    function getStrategyConfig(address strategy) public view returns (StrategyConfig memory) {
        return strategies[strategy];
    }

    function getPosition(uint256 nftId) public view returns (PositionLedgerLib.LedgerEntry memory) {
        return ledger.getLedgerEntry(nftId);
    }

    ///////////// Internal functions /////////////

    function _unwindPosition(
        PositionLedgerLib.LedgerEntry memory position,
        SwapAdapter.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        internal
        returns (uint256 wbtcReceived)
    {
        // Unwind the position
        uint256 assetsReceived = leverageDepositor.redeem(position.strategyAddress, position.strategyShares);
        address strategyAsset = IMultiPoolStrategy(position.strategyAddress).asset();
        // Swap the assets to WBTC
        IERC20(strategyAsset).transfer(address(swapAdapter), assetsReceived);
        wbtcReceived =
            swapAdapter.swap(IERC20(strategyAsset), wbtc, assetsReceived, exchange, swapData, swapRoute, address(this));
    }

    function _getWBTCValueFromTokenAmount(
        address token,
        uint256 amount
    )
        internal
        view
        returns (uint256 tokenValueInWBTC)
    {
        uint256 tokenPriceInUSD = _getLatestPrice(token);
        uint256 wbtcPriceInUSD = _getLatestPrice(address(wbtc));

        uint256 tokenValueInWBTCUnadjustedDecimals = ((amount * uint256(tokenPriceInUSD)) / (uint256(wbtcPriceInUSD)));

        tokenValueInWBTC = _adjustDecimalsToWBTCDecimals(token, tokenValueInWBTCUnadjustedDecimals);
    }

    function _adjustDecimalsToWBTCDecimals(
        address fromToken,
        uint256 amountUnadjustedDecimals
    )
        internal
        view
        returns (uint256)
    {
        uint8 fromTokenDecimals = IERC20Detailed(fromToken).decimals();
        uint8 fromTokenOracleDecimals = (oracles[fromToken]).decimals();
        uint8 wbtcOracleDecimals = (oracles[address(wbtc)]).decimals();

        uint256 fromDec = fromTokenDecimals + fromTokenOracleDecimals;
        uint256 toDec = wbtcOracleDecimals + WBTC_DECIMALS;

        if (fromDec > toDec) {
            return amountUnadjustedDecimals / 10 ** (fromDec - toDec);
        } else {
            return amountUnadjustedDecimals * 10 ** (toDec - fromDec);
        }
    }

    /**
     * @notice Get the token prices from oracles and check if the received token amount is enough
     * @param targetToken Token of the strategy
     * @param wbtcAmount Total WBTC amount to swap and deposit into strategy
     * @return expectedTargetTokenAmount Expected amount of target token
     */
    function _checkOracles(
        address targetToken,
        uint256 wbtcAmount
    )
        internal
        view
        returns (uint256 expectedTargetTokenAmount)
    {
        uint8 targetTokenDecimals = IERC20Detailed(targetToken).decimals();
        uint8 targetTokenOracleDecimals = (oracles[targetToken]).decimals();
        uint256 wbtcPrice = _getLatestPrice(address(wbtc)); // in USD
        uint256 targetTokenPrice = _getLatestPrice(targetToken); // in USD

        expectedTargetTokenAmount = (
            (
                (wbtcAmount * wbtcPrice / 10 ** WBTC_DECIMALS)
                    * (10 ** (targetTokenDecimals + targetTokenOracleDecimals)) / 10 ** WBTC_DECIMALS
            ) / targetTokenPrice
        );
    }

    /**
     * @notice Get the latest price of a token from its oracle
     * @param token Token address
     */
    function _getLatestPrice(address token) internal view returns (uint256 uPrice) {
        IOracle oracle = oracles[token];
        if (address(oracle) == address(0)) revert OracleNotSet();

        (, int256 price,,,) = oracle.latestRoundData();

        if (price < 0) revert OraclePriceError();

        uPrice = uint256(price);
    }

    error ExceedBorrowLimit();
    error LessThanMinimumShares();
    error OracleNotSet();
    error NotEnoughTokensReceived();
    error OraclePriceError();
    error ExceedBorrowQuota();
    error NotOwner();
    error PositionNotLive();
    error PositionNotExpiredOrLiquidated();
    error NotEnoughWBTC();
    error NotEligibleForLiquidation();

    event StrategyConfigUpdated(
        address indexed strategy,
        uint256 quota,
        uint256 positionLifetime,
        uint256 maximumMultiplier,
        uint256 liquidationBuffer,
        uint256 liquidationFee
    );
    event StrategyRemoved(address indexed strategy);
    event GlobalParameterUpdated(string parameter, uint256 value);
    event FeeCollectorUpdated(address newFeeCollector);
    event MonitorUpdated(address newMonitor);
    event ExpiredVaultUpdated(address newExpiredVault);
    event StrategyLiquidationFeeUpdated(address strategy, uint256 fee);
    event PositionOpened(
        uint256 indexed nftId,
        address indexed user,
        address indexed strategy,
        uint256 collateralAmount,
        uint256 wbtcToBorrow,
        uint256 positionExpireBlock,
        uint256 sharesReceived,
        uint256 liquidationBuffer
    );
    event PositionClosed(
        uint256 indexed nftId,
        address indexed user,
        address indexed strategy,
        uint256 receivedAmount,
        uint256 wbtcDebtAmount,
        uint256 exitFee
    );
    event OracleSet(address token, IOracle oracle);
}
