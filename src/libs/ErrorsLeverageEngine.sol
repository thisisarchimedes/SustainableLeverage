// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

library ErrorsLeverageEngine {

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
    error InsufficientFunds();
    error PositionHasNoBalance();
    error SwapAdapterAlreadySet();
    error PositionMustLiveForMinDuration();
}
