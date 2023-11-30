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
import { LocalRoles } from "./libs/LocalRoles.sol";
import { DependencyAddresses } from "./libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "./libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "./libs/EventsLeverageEngine.sol";

/// @title LeverageEngine Contract
/// @notice This contract facilitates the management of strategy configurations and admin parameters for the Leverage
/// Engine.
/// @notice Leverage Engine is upgradable

contract LeverageEngine is ILeverageEngine, AccessControlUpgradeable {
  using PositionLedgerLib for PositionLedgerLib.LedgerStorage;
  using SafeERC20 for IERC20;
  using LocalRoles for *;
  using ErrorsLeverageEngine for *;
  using EventsLeverageEngine for *;

  uint256 internal constant BASE_DENOMINATOR = 10_000;
  uint8 internal constant WBTC_DECIMALS = 8;
  IERC20 internal constant wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

  address public monitor;

  IWBTCVault internal wbtcVault;
  PositionToken internal positionToken;
  ILeverageDepositor internal leverageDepositor;
  SwapAdapter internal swapAdapter;

  address internal expiredVault;

  mapping(address => StrategyConfig) internal strategies;

  /// Mapping of oracles token => oracle
  mapping(address => IOracle) public oracles;

  // Global admin parameters
  uint256 public exitFee; // Fee (taken from profits) taken after returning all debt during exit by user in 10000 (For
  // example: 50 is 0.5%)
  address public feeCollector; // Address that collects fees in 10000

  PositionLedgerLib.LedgerStorage internal ledger;

  constructor() {
    _disableInitializers();
  }

  function initialize() external initializer {
    __AccessControl_init();
    _grantRole(LocalRoles.ADMIN_ROLE, msg.sender);

    exitFee = 50;
  }

  function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(LocalRoles.ADMIN_ROLE) {
    leverageDepositor = ILeverageDepositor(dependencies.leverageDepositor);
    positionToken = PositionToken(dependencies.positionToken);
    swapAdapter = SwapAdapter(dependencies.swapAdapter);
    wbtcVault = IWBTCVault(dependencies.wbtcVault);

    setExpiredVault(dependencies.expiredVault);

    wbtc.approve(dependencies.wbtcVault, type(uint256).max);
  }

  ///////////// Admin functions /////////////

  function setStrategyConfig(
    address strategy,
    StrategyConfig calldata config
  ) external onlyRole(LocalRoles.ADMIN_ROLE) {
    require(
      config.maximumMultiplier < (1e16 / (config.liquidationBuffer - 10 ** WBTC_DECIMALS)),
      "Invalid MM or LB ratio"
    );

    strategies[strategy] = config;

    emit EventsLeverageEngine.StrategyConfigUpdated(
      strategy,
      config.quota,
      config.positionLifetime,
      config.maximumMultiplier,
      config.liquidationBuffer,
      config.liquidationFee
    );
  }

  function removeStrategy(address strategy) external onlyRole(LocalRoles.ADMIN_ROLE) {
    require(strategies[strategy].quota > 0, "Strategy not active");

    delete strategies[strategy];

    emit EventsLeverageEngine.StrategyRemoved(strategy);
  }

  function setOracle(address token, IOracle oracle) external onlyRole(LocalRoles.ADMIN_ROLE) {
    oracles[token] = oracle;
    emit EventsLeverageEngine.OracleSet(token, oracle);
  }

  function changeSwapAdapter(address _swapAdapter) external onlyRole(LocalRoles.ADMIN_ROLE) {
    swapAdapter = SwapAdapter(_swapAdapter);
  }

  /// @notice Set the global exit fee.
  /// @notice Charge when user closes a position (not on liquidation or expiration)
  /// @notice meant to prevent economic attacks
  /// @param fee The new exit fee percentage.
  function setExitFee(uint256 fee) external onlyRole(LocalRoles.ADMIN_ROLE) {
    exitFee = fee;
    emit EventsLeverageEngine.GlobalParameterUpdated("ExitFee", fee);
  }

  function setFeeCollector(address collector) external onlyRole(LocalRoles.ADMIN_ROLE) {
    feeCollector = collector;
    emit EventsLeverageEngine.FeeCollectorUpdated(collector);
  }

  function setMonitor(address _monitor) external onlyRole(LocalRoles.ADMIN_ROLE) {
    if (monitor != address(0)) {
      _revokeRole(LocalRoles.MONITOR_ROLE, monitor);
    }
    monitor = _monitor;
    _grantRole(LocalRoles.MONITOR_ROLE, _monitor);
    emit EventsLeverageEngine.MonitorUpdated(_monitor);
  }

  function setExpiredVault(address _expiredVault) public onlyRole(LocalRoles.ADMIN_ROLE) {
    if (expiredVault != address(0)) {
      wbtc.approve(expiredVault, 0);
      _revokeRole(LocalRoles.EXPIRED_VAULT_ROLE, expiredVault);
    }

    expiredVault = _expiredVault;
    _grantRole(LocalRoles.EXPIRED_VAULT_ROLE, _expiredVault);
    wbtc.approve(_expiredVault, type(uint256).max);

    emit EventsLeverageEngine.ExpiredVaultUpdated(_expiredVault);
  }

  function setLiquidationFee(address strategy, uint256 fee) external onlyRole(LocalRoles.ADMIN_ROLE) {
    strategies[strategy].liquidationFee = fee;

    emit EventsLeverageEngine.StrategyLiquidationFeeUpdated(strategy, fee);
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
  ) external returns (uint256 nftId) {
    // update strategy qouta - reduce by the amount of borrowed WBTC and it would revert if the strategy has no
    // quota
    strategies[strategy].quota -= wbtcToBorrow;
    // Check Maximum Multiplier condition
    if ((collateralAmount * strategies[strategy].maximumMultiplier) / 10 ** WBTC_DECIMALS < wbtcToBorrow) {
      revert ErrorsLeverageEngine.ExceedBorrowLimit();
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
      if (wbtcToBorrow >= (receivedTokensInWbtc * strategies[strategy].liquidationBuffer) / 10 ** WBTC_DECIMALS) {
        revert ErrorsLeverageEngine.NotEnoughTokensReceived();
      }
    }

    // Deposit borrowed WBTC to LeverageDepositor->strategy and get back shares
    uint256 sharesReceived = leverageDepositor.deposit(strategy, strategyUnderlyingToken, receivedAmount);
    if (sharesReceived < minStrategyShares) revert ErrorsLeverageEngine.LessThanMinimumShares();
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
    nftId = positionToken.mint(msg.sender); // Mint NFT and send to user
    ledger.setLedgerEntry(nftId, newEntry);

    // emit event
    emit EventsLeverageEngine.PositionOpened(
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
  ) external {
    // Check if the user owns the NFT
    if (positionToken.ownerOf(nftId) != msg.sender) revert ErrorsLeverageEngine.NotOwner();

    PositionLedgerLib.LedgerEntry memory position = ledger.entries[nftId];

    // Check if the NFT state is LIVE
    if (position.state != PositionLedgerLib.PositionState.LIVE) revert ErrorsLeverageEngine.PositionNotLive();

    // Unwind the position
    uint256 wbtcReceived = _unwindPosition(position, swapRoute, swapData, exchange);

    // Repay WBTC debt
    if (wbtcReceived < position.wbtcDebtAmount) revert ErrorsLeverageEngine.NotEnoughWBTC();

    // Return WBTC debt to WBTC vault
    wbtcVault.repay(nftId, position.wbtcDebtAmount);

    // Deduct the exit fee
    uint256 exitFeeAmount = ((wbtcReceived - position.wbtcDebtAmount) * exitFee) / BASE_DENOMINATOR;
    wbtc.transfer(feeCollector, exitFeeAmount);

    // Send the rest of WBTC to the user
    uint256 wbtcLeft = wbtcReceived - position.wbtcDebtAmount - exitFeeAmount;
    if (wbtcLeft < minWBTC) revert ErrorsLeverageEngine.NotEnoughTokensReceived();
    wbtc.transfer(msg.sender, wbtcLeft);

    // Update the ledger
    position.state = PositionLedgerLib.PositionState.CLOSED;
    ledger.setLedgerEntry(nftId, position);

    // Burn the NFT
    positionToken.burn(nftId);

    // emit event
    emit EventsLeverageEngine.PositionClosed(
      nftId,
      msg.sender,
      position.strategyAddress,
      wbtcLeft,
      position.wbtcDebtAmount,
      exitFeeAmount
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
  ) external onlyRole(LocalRoles.MONITOR_ROLE) {
    PositionLedgerLib.LedgerEntry memory position = getPosition(nftId);

    if (position.state != PositionLedgerLib.PositionState.LIVE) revert ErrorsLeverageEngine.PositionNotLive();

    uint256 wbtcReceived = _unwindPosition(position, swapRoute, swapData, exchange);

    // Repay WBTC debt
    if (wbtcReceived > (position.wbtcDebtAmount * position.liquidationBuffer) / (10 ** WBTC_DECIMALS)) {
      revert ErrorsLeverageEngine.NotEligibleForLiquidation();
    }

    if (wbtcReceived < minWBTC) revert ErrorsLeverageEngine.NotEnoughTokensReceived();

    // Return WBTC debt to WBTC vault
    wbtcVault.repay(nftId, position.wbtcDebtAmount);

    if (wbtcReceived > position.wbtcDebtAmount) {
      uint256 wbtcLeft = wbtcReceived - position.wbtcDebtAmount;
      uint256 liquidationFeeAmount = (getStrategyConfig(position.strategyAddress).liquidationFee * wbtcLeft) /
        (10 ** WBTC_DECIMALS);
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
  function closeExpiredOrLiquidatedPosition(
    uint256 nftID,
    address sender
  ) external onlyRole(LocalRoles.EXPIRED_VAULT_ROLE) {
    // Check if the user owns the NFT
    if (positionToken.ownerOf(nftID) != sender) revert ErrorsLeverageEngine.NotOwner();

    PositionLedgerLib.LedgerEntry storage position = ledger.entries[nftID];

    // Check if the NFT state is Expired or Liquidated
    if (
      position.state != PositionLedgerLib.PositionState.EXPIRED &&
      position.state != PositionLedgerLib.PositionState.LIQUIDATED
    ) revert ErrorsLeverageEngine.PositionNotExpiredOrLiquidated();

    // Rememver the received amount for emitting the event
    uint256 receivedAmount = position.claimableAmount;

    // Update the ledger
    position.state = PositionLedgerLib.PositionState.CLOSED;
    position.claimableAmount = 0;

    // Burn the NFT
    positionToken.burn(nftID);

    // Emit event
    // No exit fee is charged for expired positions
    emit EventsLeverageEngine.PositionClosed(
      nftID,
      sender,
      position.strategyAddress,
      receivedAmount,
      position.wbtcDebtAmount,
      0
    );
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
  ) external view returns (uint256 estimatedShares) {
    if (strategies[strategy].quota < wbtcToBorrow) revert ErrorsLeverageEngine.ExceedBorrowQuota();
    // Check Maximum Multiplier condition
    if ((collateralAmount * strategies[strategy].maximumMultiplier) / 10 ** WBTC_DECIMALS < wbtcToBorrow) {
      revert ErrorsLeverageEngine.ExceedBorrowLimit();
    }

    // Here, we make an assumption that the strategy has a function to give us an estimate of the shares
    estimatedShares = IMultiPoolStrategy(strategy).previewDeposit(minimumExpected);
  }

  function isPositionLiquidatable(uint256 nftId) external view returns (bool) {
    PositionLedgerLib.LedgerEntry memory position = getPosition(nftId);

    if (position.state != PositionLedgerLib.PositionState.LIVE) revert ErrorsLeverageEngine.PositionNotLive();

    uint256 positionValue = previewPositionValueInWBTC(nftId);

    return positionValue < (position.wbtcDebtAmount * position.liquidationBuffer) / (10 ** WBTC_DECIMALS);
  }

  function previewPositionValueInWBTC(uint256 nftId) public view returns (uint256 positionValueInWBTC) {
    PositionLedgerLib.LedgerEntry memory position = getPosition(nftId);
    uint256 strategyValueTokenEstimatedAmount = IMultiPoolStrategy(position.strategyAddress).convertToAssets(
      position.strategyShares
    );
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

  function getCurrentExpiredVault() public view returns (address) {
    return expiredVault;
  }

  ///////////// Internal functions /////////////

  function _unwindPosition(
    PositionLedgerLib.LedgerEntry memory position,
    SwapAdapter.SwapRoute swapRoute,
    bytes calldata swapData,
    address exchange
  ) internal returns (uint256 wbtcReceived) {
    // Unwind the position
    uint256 assetsReceived = leverageDepositor.redeem(position.strategyAddress, position.strategyShares);
    address strategyAsset = IMultiPoolStrategy(position.strategyAddress).asset();
    // Swap the assets to WBTC
    IERC20(strategyAsset).transfer(address(swapAdapter), assetsReceived);
    wbtcReceived = swapAdapter.swap(
      IERC20(strategyAsset),
      wbtc,
      assetsReceived,
      exchange,
      swapData,
      swapRoute,
      address(this)
    );
  }

  function _getWBTCValueFromTokenAmount(
    address token,
    uint256 amount
  ) internal view returns (uint256 tokenValueInWBTC) {
    uint256 tokenPriceInUSD = _getLatestPrice(token);
    uint256 wbtcPriceInUSD = _getLatestPrice(address(wbtc));

    uint256 tokenValueInWBTCUnadjustedDecimals = ((amount * uint256(tokenPriceInUSD)) / (uint256(wbtcPriceInUSD)));

    tokenValueInWBTC = _adjustDecimalsToWBTCDecimals(token, tokenValueInWBTCUnadjustedDecimals);
  }

  function _adjustDecimalsToWBTCDecimals(
    address fromToken,
    uint256 amountUnadjustedDecimals
  ) internal view returns (uint256) {
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
  ) internal view returns (uint256 expectedTargetTokenAmount) {
    uint8 targetTokenDecimals = IERC20Detailed(targetToken).decimals();
    uint8 targetTokenOracleDecimals = (oracles[targetToken]).decimals();
    uint256 wbtcPrice = _getLatestPrice(address(wbtc)); // in USD
    uint256 targetTokenPrice = _getLatestPrice(targetToken); // in USD

    expectedTargetTokenAmount = (((((wbtcAmount * wbtcPrice) / 10 ** WBTC_DECIMALS) *
      (10 ** (targetTokenDecimals + targetTokenOracleDecimals))) / 10 ** WBTC_DECIMALS) / targetTokenPrice);
  }

  /**
   * @notice Get the latest price of a token from its oracle
   * @param token Token address
   */
  function _getLatestPrice(address token) internal view returns (uint256 uPrice) {
    IOracle oracle = oracles[token];
    if (address(oracle) == address(0)) revert ErrorsLeverageEngine.OracleNotSet();

    (, int256 price, , , ) = oracle.latestRoundData();

    if (price < 0) revert ErrorsLeverageEngine.OraclePriceError();

    uPrice = uint256(price);
  }
}
