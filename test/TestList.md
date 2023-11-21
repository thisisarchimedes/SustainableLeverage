
# Test list:
    * Set liquidation buffer per strategy V
    * Set liquidation fees V
    * Get current position value in WBTC (esitmation) - for USDC position (6 decimals) V
    * Get current position value in WBTC (esitmation) - for ETH position (18 decimals) V
    * check if position is eligible for liquidation V
    * Call liquidation and check if poistion state is live
    * Calc preview to how much WBTC we will get (so we can send a min to liquidation and avoid attacks)
    * liquidate position if it is eligible for liquidation
    * move whatever left after liquidation to Exprired Vault
    * Even if there is nothing left move 0 to expire vault
    * Collect liquidation fees
    * Detect when the total value of the position is less than debt during liquidation
    * Only Monitor can liquidate position
    * Check that position state is LIQUIDATED after liquidation


    * Check that position state is live when there is a position
    * Check that when we don't have a position the position state is correct


    0. testGetWBTCAmountForTokenXWithLessThan8Decimals
    1. Getting the WBTC price for underlying token
    3. liquidate position

# Refactor list:
    1. Oracle contract should be upgradable in case we want to switch Chainlink
    2. Change leverageEngine current Oracle to Oracle contract
    3. Have a fallback Oracle. Check if Oracle is healthy and if not revert to fallback Oracle
    4. Leverage Engine gets the contract address of our Oracle wrapper and we can change it if we want to (one Oracle instance for all tokens)
  

  # Comments

  - Liquidation buffer is same decimal as debt (WBTC - 8 decimals), and is represented as >1 number (1.1, 1.2, 1.3 etc)
  - Liquidation fee per strategy and the same decimal as debt (WBTC - 8 decimals). It is a %
  - Have the Oracle upgradeable so we can switch from Chainlink if we want to