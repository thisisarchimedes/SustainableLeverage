# Test list:

    [x] Set liquidation buffer per strategy V
    [x] Set liquidation fees V
    [x] Get current position value in WBTC (esitmation) - for USDC position (6 decimals) V
    [x] Get current position value in WBTC (esitmation) - for ETH position (18 decimals) V
    [x] check if position is eligible for liquidation V
    [x] Call liquidation and revert if poistion state is not live V
    [x] Call liquidation and check if poistion state is liveV
    [x] Calc preview to how much WBTC we will get (so we can send a min to liquidation and avoid attacks) V
    [x] liquidate position if it is eligible for liquidation (ETH value asset position) - enough WBTC in position to cover debt
    [x] liquidate position if it is eligible for liquidation (USDC value asset position) - enough WBTC in position to cover debt
    [] liquidate position if it is eligible for liquidation (ETH value asset position) - NOT enough WBTC in position to cover debt
    [x] move whatever left after liquidation to Exprired Vault
    [] Even if there is nothing left move 0 to expire vault
    [x] Collect liquidation fees
    [] Detect when the total value of the position is less than debt during liquidation
    [] Only Monitor can liquidate position
    [x] Check that position state is LIQUIDATED after liquidation
    [] Check that position state is live when there is a position
    [] Check that when we don't have a position the position state is correct

# Refactor list:

    1. Oracle contract should be upgradable in case we want to switch Chainlink
    2. Change leverageEngine current Oracle to Oracle contract
    3. Have a fallback Oracle. Check if Oracle is healthy and if not revert to fallback Oracle
    4. Leverage Engine gets the contract address of our Oracle wrapper and we can change it if we want to (one Oracle instance for all tokens)

# Comments

- Liquidation buffer is same decimal as debt (WBTC - 8 decimals), and is represented as >1 number (1.1, 1.2, 1.3 etc)
- Liquidation fee per strategy and the same decimal as debt (WBTC - 8 decimals). It is a %
- Have the Oracle upgradeable so we can switch from Chainlink if we want to
- Move swapDatas inside openPosition function as TS is struggling with decoding
- Check access control to function


---

# refactoring notes

[X] Clean up SwapAdapter replace it with SwapManager
[X] Decouple the contracts initalization and have the same code running in Deploy and tests
[] Hold shares with Ledger

[] setOracle should get 2 tokens also getOracle price should get two tokens + add getOracleDecimals
[] add no immediate close position (force 50 block cool down)
[] test_DetectPoolManipulation implement

[] Test: external cannot call ADMIN, INTERNAL CONTRACT and MONITOR functions
[] Only upgradable the contracts that hold WBTC or shares (and data like Ledger)
[] remove the bare strcut of position ledger outside of the contract

[] Fix swapAdapter make it more generic wrapper
[] LeverageDepositor no access control?
[] look for TODOs and address them

[] Remove the overloaded openPosition

# Architecture

- ProtocolParameters: Manages global admin parameters
- LeveragedStrategy: Handles strategy configuration (change the name)
- OracleManager: Manage oracles and pricing information
- PositionOpener: Open a leveraged position
- PostionCloser: Close a leveraged position
- LedgerManager: Manages the position ledger
- ExpiredVault: Holds expired positions
- WBTC: WBTC token

