# Test list:

[X] Set liquidation buffer per strategy
[X] Set liquidation fees
[X] Get current position value in WBTC (esitmation) - for USDC position (6 decimals) 
[X] Get current position value in WBTC (esitmation) - for ETH position (18 decimals) 
[X] check if position is eligible for liquidation 
[X] Call liquidation and revert if poistion state is not live 
[X] Call liquidation and check if poistion state is liveV
[X] Calc preview to how much WBTC we will get (so we can send a min to liquidation and avoid attacks) 
[X] liquidate position if it is eligible for liquidation (ETH value asset position) - enough WBTC in position to cover debt
[X] liquidate position if it is eligible for liquidation (USDC value asset position) - enough WBTC in position to cover debt
[X] Check that position state is LIQUIDATED after liquidation
[X] move whatever left after liquidation to Exprired Vault
[X] Collect liquidation fees
[X] Only Monitor can liquidate position
[X] Check that position state is live when there is a position
[] Detect when the total value of the position is less than debt during liquidation
[] Check that when we don't have a position the position state is correct
[] liquidate position if it is eligible for liquidation (ETH value asset position) - NOT enough WBTC in position to cover debt
[] test that we enforce minBTC to avoid sandwitch

# Refactor list:

[X] Clean up SwapAdapter replace it with SwapManager
[X] Decouple the contracts initalization and have the same code running in Deploy and tests

[X] setOracle should get 2 tokens also getOracle price should get two tokens + add getOracleDecimals
[X] add no immediate close position (force X block cool down)
[] test_DetectPoolManipulation implement

[] Test: external cannot call ADMIN, INTERNAL CONTRACT and MONITOR functions
[] Only upgradable the contracts that hold WBTC or shares (and data like Ledger)
[] remove the bare strcut of position ledger outside of the contract

[] Fix swapAdapter make it more generic wrapper
[] LeverageDepositor no access control?
[] look for TODOs and address them

[] Have a fallback Oracle. Check if Oracle is healthy and if not revert to fallback Oracle
[] Remove the overloaded openPosition

[] Consider moving PositionLedger and PositionToken under LeveragedStrategy
[] Consider hiding OracleManager under LeveragedStrategy

[] Search all files for TODOs

# Comments

- Liquidation buffer is same decimal as debt (WBTC - 8 decimals), and is represented as >1 number (1.1, 1.2, 1.3 etc)
- Liquidation fee per strategy and the same decimal as debt (WBTC - 8 decimals). It is a %
- Have the Oracle upgradeable so we can switch from Chainlink if we want to
- Move swapDatas inside openPosition function as TS is struggling with decoding
- Check access control to function


# Architecture

- ProtocolParameters: Manages global admin parameters
- LeveragedStrategy: Handles strategy configuration (change the name)
- OracleManager: Manage oracles and pricing information
- PositionOpener: Open a leveraged position
- PostionCloser: Close a leveraged position
- LedgerManager: Manages the position ledger
- ExpiredVault: Holds expired positions
- WBTC: WBTC token


PositionOpenner,Closer,Liq,exirpe inhartiance from a common contract with params and swap methods
Standarize swapStrategyTokenToWbtc and swapStrategyToWbtcToToken across files