// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/ILeverageEngine.sol";
import "./interfaces/IERC20Detailed.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "./PositionLedgerLib.sol";
import { IWBTCVault } from "./interfaces/IWBTCVault.sol";
import { ILeverageDepositor } from "./interfaces/ILeverageDepositor.sol";
import { IOracle } from "./interfaces/IOracle.sol";
import { PositionToken } from "./PositionToken.sol";
import { SwapAdapter } from "./SwapAdapter.sol";
import { IMultiPoolStrategy } from "./interfaces/IMultiPoolStrategy.sol";
import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";

/// @title LeverageEngine Contract
/// @notice This contract facilitates the management of strategy configurations and admin parameters for the Leverage
/// Engine.
/// @notice Leverage Engine is upgradable
contract LeverageEngine is ILeverageEngine, AccessControlUpgradeable {
    using PositionLedgerLib for PositionLedgerLib.LedgerStorage;
    using SafeERC20 for IERC20;

    // Define roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");
    bytes32 public constant EXPIRED_VAULT_ROLE = keccak256("EXPIRED_VAULT_ROLE");
    uint256 constant BASE_DENOMINATOR = 10_000;
    uint8 public constant WBTC_DECIMALS = 8;

    // WBTC token
    IERC20 public wbtc;

    // WBTC Vault
    IWBTCVault public wbtcVault;

    // Position NFT
    PositionToken public nft;

    // Leverage Depositor
    ILeverageDepositor public leverageDepositor;

    // Swap Adapter
    SwapAdapter public swapAdapter;


    // Expired Vault
    address public expiredVault;
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
        uint256 liquidationFee;
    }

    enum StrategyConfigUpdate {
        QUOTA,
        POSITION_LIFETIME,
        MAXIMUM_MULTIPLIER,
        LIQUIDATION_BUFFER
    }

    // Mapping of strategies to their configurations
    mapping(address => StrategyConfig) internal strategies;

    /// Mapping of oracles token => oracle
    mapping(address => IOracle) public oracles;

    // Global admin parameters
    uint256 public exitFee; // Fee (taken from profits) taken after returning all debt during exit by user in 10000
    address public feeCollector; // Address that collects fees in 10000
    uint256 public openPositionSlippage; // in 10000 so 10000 = 100%

    //Errors
    error ExceedBorrowLimit();
    error LessThanMinimumShares();
    error OracleNotSet();
    error NotEnoughTokensReceived();
    error OraclePriceError();
    error ExceedBorrowQuota();
    error NotOwner();
    error PositionNotLive();
    error PositionNotExpired();
    error NotEnoughWBTC();

    // Events
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
    event ExpiredVaultUpdated(address newExpiredVault);
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
        _grantRole(ADMIN_ROLE, msg.sender);
        wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        wbtcVault = IWBTCVault(_wbtcVault);
        wbtc.approve(_wbtcVault, type(uint256).max);
        leverageDepositor = ILeverageDepositor(_leverageDepositor);
        nft = PositionToken(_nft);
        swapAdapter = SwapAdapter(_swapAdapter);
        openPositionSlippage = 100;
        exitFee = 50;
        feeCollector = _feeCollector;
    }

    ///////////// Admin functions /////////////

    /// @notice Set the configuration for a specific strategy.
    /// @dev Validates the relationship between MM and LB before setting the config.
    /// @param config StrategyConfig structs that holds the config variables
    function setStrategyConfig(address strategy, StrategyConfig calldata config) external onlyRole(ADMIN_ROLE) {
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
    function removeStrategy(address strategy) external onlyRole(ADMIN_ROLE) {
        require(strategies[strategy].quota > 0, "Strategy not active");

        delete strategies[strategy];

        emit StrategyRemoved(strategy);
    }

    /**
     *  @notice Set the oracle address for a token
     * @param token address of the token
     * @param oracle address of the oracle
     */
    function setOracle(address token, IOracle oracle) external onlyRole(ADMIN_ROLE) {
        oracles[token] = oracle;
        emit OracleSet(token, oracle);
    }

    /**
     * @notice Change the swap adapter address
     * @param _swapAdapter The address of the new swap adapter.
     */
    function changeSwapAdapter(address _swapAdapter) external onlyRole(ADMIN_ROLE) {
        swapAdapter = SwapAdapter(_swapAdapter);
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

    /// @notice Set the expired vault role.
    /// @param _expiredVault The new expired vault address.
    function setExpiredVault(address _expiredVault) external onlyRole(ADMIN_ROLE) {
        if (expiredVault != address(0)) {
            _revokeRole(EXPIRED_VAULT_ROLE, expiredVault);
        }
        expiredVault = _expiredVault;
        _grantRole(EXPIRED_VAULT_ROLE, _expiredVault);
        emit ExpiredVaultUpdated(_expiredVault);
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
        uint256 expectedTargetTokenAmount = _checkOracles(strategyUnderlyingToken, totalAmount);
        if (receivedAmount < expectedTargetTokenAmount) revert NotEnoughTokensReceived();
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
        uint256 assetsReceived = leverageDepositor.redeem(position.strategyAddress, position.strategyShares);
        address strategyAsset = IMultiPoolStrategy(position.strategyAddress).asset();
        // Swap the assets to WBTC
        IERC20(strategyAsset).transfer(address(swapAdapter), assetsReceived);
        uint256 wbtcReceived =
            swapAdapter.swap(IERC20(strategyAsset), wbtc, assetsReceived, exchange, swapData, swapRoute, address(this));
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

    /// @notice ExpiredVault will call this function to close an expired position.
    /// @param nftID The ID of the NFT representing the position.
    function closeExpiredPosition(uint256 nftID, address sender) external onlyRole(EXPIRED_VAULT_ROLE) {
        // Check if the user owns the NFT
        if (nft.ownerOf(nftID) != sender) revert NotOwner();

        PositionLedgerLib.LedgerEntry storage position = ledger.entries[nftID];

        // Check if the NFT state is LIVE
        if (position.state != PositionLedgerLib.PositionState.EXPIRED) revert PositionNotExpired();

        // Rememver the received amount for emitting the event
        uint256 receivedAmount = position.claimableAmount;

        // Update the ledger
        position.state = PositionLedgerLib.PositionState.CLOSED;
        position.claimableAmount = 0;

        // Burn the NFT
        nft.burn(nftID);

        // Emit event
        // No exit fee is charged for expired positions
        emit PositionClosed(nftID, sender, position.strategyType, receivedAmount, position.wbtcDebtAmount, 0);
    }

    /// @notice Get the configuration for a specific strategy.
    /// @param strategy The address of the strategy to retrieve configuration for.
    /// @return The strategy configuration.
    function getStrategyConfig(address strategy) external view returns (StrategyConfig memory) {
        return strategies[strategy];
    }

    function getPosition(uint256 nftId) public view returns (PositionLedgerLib.LedgerEntry memory) {
        return ledger.getLedgerEntry(nftId);
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
        ) * (BASE_DENOMINATOR - openPositionSlippage) / BASE_DENOMINATOR;
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
}
