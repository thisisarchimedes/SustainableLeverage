
# Test list:
    0. testGetWBTCAmountForTokenXWithLessThan8Decimals
    1. Getting the WBTC price for underlying token
    2. check if position is eligible for liquidation
    3. liquidate position

# Refactor list:
    1. Oracle contract should be upgradable in case we want to switch Chainlink
    2. Change leverageEngine current Oracle to Oracle contract
    3. Have a fallback Oracle. Check if Oracle is healthy and if not revert to fallback Oracle
    4. Leverage Engine gets the contract address of our Oracle wrapper and we can change it if we want to (one Oracle instance for all tokens)
  