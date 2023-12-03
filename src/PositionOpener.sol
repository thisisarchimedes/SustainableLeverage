// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

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
import { ProtocolRoles } from "./libs/ProtocolRoles.sol";
import { DependencyAddresses } from "./libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "./libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "./libs/EventsLeverageEngine.sol";
import { LeveragedStrategy } from "./LeveragedStrategy.sol";
import { ProtocolParameters } from "./ProtocolParameters.sol";
import { OracleManager } from "./OracleManager.sol";
import { PositionLedger, LedgerEntry, PositionState } from "./PositionLedger.sol";

/// @title PositionManager Contract
/// @notice Supports only WBTC tokens for now
contract PositionOpener is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    uint256 internal constant BASE_DENOMINATOR = 10_000;
    uint8 internal constant WBTC_DECIMALS = 8;
    IERC20 internal constant wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    IWBTCVault internal wbtcVault;
    PositionToken internal positionToken;
    ILeverageDepositor internal leverageDepositor;
    SwapAdapter internal swapAdapter;
    LeveragedStrategy internal leveragedStrategy;
    ProtocolParameters internal protocolParameters;
    OracleManager internal oracleManager;
    PositionLedger internal positionLedger;

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setDependencies(DependencyAddresses calldata dependencies) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        leverageDepositor = ILeverageDepositor(dependencies.leverageDepositor);
        positionToken = PositionToken(dependencies.positionToken);
        swapAdapter = SwapAdapter(dependencies.swapAdapter);
        wbtcVault = IWBTCVault(dependencies.wbtcVault);
        leveragedStrategy = LeveragedStrategy(dependencies.leveragedStrategy);
        protocolParameters = ProtocolParameters(dependencies.protocolParameters);
        oracleManager = OracleManager(dependencies.oracleManager);
        positionLedger = PositionLedger(dependencies.positionLedger);
    }

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
        if (leveragedStrategy.isCollateralToBorrowRatioAllowed(strategy, collateralAmount, wbtcToBorrow) == false) {
            revert ErrorsLeverageEngine.ExceedBorrowLimit();
        }

        leveragedStrategy.reduceQuotaBy(strategy, wbtcToBorrow);

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

        // we don't want to open a position that is immediatly liquidable
        uint256 receivedTokensInWbtc =
            leveragedStrategy.getWBTCValueFromTokenAmount(strategyUnderlyingToken, receivedAmount);
        if (leveragedStrategy.isPositionLiquidatable(strategy, receivedTokensInWbtc, wbtcToBorrow) == true) {
            revert ErrorsLeverageEngine.NotEnoughTokensReceived();
        }

        // Deposit borrowed WBTC to LeverageDepositor->strategy and get back shares
        uint256 sharesReceived = leverageDepositor.deposit(strategy, strategyUnderlyingToken, receivedAmount);
        if (sharesReceived < minStrategyShares) revert ErrorsLeverageEngine.LessThanMinimumShares();

        // Update Ledger
        LedgerEntry memory newEntry;
        newEntry.collateralAmount = collateralAmount;
        newEntry.strategyAddress = strategy;
        newEntry.strategyShares = sharesReceived;
        newEntry.wbtcDebtAmount = wbtcToBorrow;
        newEntry.positionExpirationBlock = block.number + leveragedStrategy.getPositionLifetime(strategy);
        newEntry.liquidationBuffer = leveragedStrategy.getLiquidationBuffer(strategy);
        newEntry.state = PositionState.LIVE;
        nftId = positionToken.mint(msg.sender); // Mint NFT and send to user
        positionLedger.createNewPositionEntry(nftId, newEntry);

        // emit event
        emit EventsLeverageEngine.PositionOpened(
            nftId,
            msg.sender,
            newEntry.strategyAddress,
            newEntry.collateralAmount,
            newEntry.wbtcDebtAmount,
            newEntry.positionExpirationBlock,
            sharesReceived,
            newEntry.liquidationBuffer
        );
    }

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
        returns (uint256)
    {
        if (leveragedStrategy.getQuota(strategy) < wbtcToBorrow) {
            revert ErrorsLeverageEngine.ExceedBorrowQuota();
        }

        if (leveragedStrategy.isCollateralToBorrowRatioAllowed(strategy, collateralAmount, wbtcToBorrow)) {
            revert ErrorsLeverageEngine.ExceedBorrowLimit();
        }

        uint256 estimatedShares = IMultiPoolStrategy(strategy).previewDeposit(minimumExpected);

        return estimatedShares;
    }
}
