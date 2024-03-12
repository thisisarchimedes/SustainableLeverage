// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

library ErrorsLeverageEngine {
    error ExceedBorrowLimit(); // 8b085be2
    error LessThanMinimumShares(); // 3beecf45
    error OracleNotSet(); // f8794e04
    error OraclePriceStale(); // 08b9f95b
    error OracleNegativePrice(); // 641f4716
    error NotEnoughTokensReceived(); // 828f02ae
    error OraclePriceError(); // fa80e24f
    error ExceedBorrowQuota(); // d7f5242d
    error NotOwner(); // 30cd7471
    error PositionNotLive(); // 5117a49b
    error PositionNotExpiredOrLiquidated(); // 382dc85b
    error NotEnoughWBTC(); // 8445ce78
    error NotEligibleForLiquidation(); // 5e6797f9
    error InsufficientFunds(); // 356680b7
    error PositionHasNoBalance(); // 1414023b
    error SwapAdapterAlreadySet(); // b33e2407
    error PositionMustLiveForMinDuration(); // 7616ad40
    error NotEligibleForExpiration(); //6db32f8f
    error AmountMustBeGreaterThanZero(); //5e85ae73
    error BlockCountTooLow(); //0d14f234
    error BlockCountTooHigh(); //4de7b564
    error SwapAdapterNotSet(); //afd1c360
}
