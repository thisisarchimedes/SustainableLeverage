// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

interface IWBTCVault {
    function borrowAmountTo(uint256 amount, address to) external;
    function repayDebt(uint256, uint256) external;

    function swapWBTCtolvBTC(uint256 amount, uint256 minAmount) external;
    function swaplvBTCtoWBTC(uint256 lvBTCAmount, uint256 minWBTCAmount) external;
    function setlvBTCPoolAddress(address lvBTCPoolAddress) external;
}
