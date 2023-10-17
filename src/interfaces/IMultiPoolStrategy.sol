// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

interface IMultiPoolStrategy {
    event Adjusted(uint256 amount, bool isAdjustIn);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event HardWork(uint256 totalClaimed, uint256 fee);
    event Initialized(uint8 version);
    event NewRewardsCycle(uint32 indexed cycleEnd, uint256 rewardAmount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    struct Adjust {
        address adapter;
        uint256 amount;
        uint256 minReceive;
    }

    struct SwapData {
        address token;
        uint256 amount;
        bytes callData;
    }

    function LIFI_DIAMOND() external view returns (address);
    function adapters(uint256) external view returns (address);
    function addAdapter(address _adapter) external;
    function addAdapters(address[] memory _adapters) external;
    function adjust(
        Adjust[] memory _adjustIns,
        Adjust[] memory _adjustOuts,
        address[] memory _sortedAdapters
    )
        external;
    function adjustInInterval() external view returns (uint256);
    function adjustOutInterval() external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function changeAdapterHealthFactor(address _adapter, uint256 _healthFactor) external;
    function changeAdjustInInterval(uint256 _adjustInInterval) external;
    function changeAdjustOutInterval(uint256 _adjustOutInterval) external;
    function changeFeePercentage(uint256 _feePercentage) external;
    function changeFeeRecipient(address _feeRecipient) external;
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function doHardWork(address[] memory _adaptersToClaim, SwapData[] memory _swapDatas) external;
    function feePercentage() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function initialize(address _stakingToken, address _monitor, string memory _name, string memory _symbol) external;
    function initialize(address _stakingToken, address _monitor) external;
    function isAdapter(address) external view returns (bool);
    function lastAdjustIn() external view returns (uint256);
    function lastAdjustOut() external view returns (uint256);
    function lastRewardAmount() external view returns (uint192);
    function lastSync() external view returns (uint32);
    function maxDeposit(address) external view returns (uint256);
    function maxMint(address) external view returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function minPercentage() external view returns (uint256);
    function monitor() external view returns (address);
    function name() external view returns (string memory);
    function owner() external view returns (address);
    function paused() external view returns (bool);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minimumReceive
    )
        external
        returns (uint256);
    function removeAdapter(address _adapter) external;
    function renounceOwnership() external;
    function rewardsCycleEnd() external view returns (uint32);
    function rewardsCycleLength() external view returns (uint32);
    function setMinimumPercentage(uint256 _minPercentage) external;
    function setMonitor(address _monitor) external;
    function storedTotalAssets() external view returns (uint256);
    function symbol() external view returns (string memory);
    function togglePause() external;
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function withdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 minimumReceive
    )
        external
        returns (uint256);
}
