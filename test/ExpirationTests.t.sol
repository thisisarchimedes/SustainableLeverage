// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import "test/BaseTest.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { IERC721A } from "ERC721A/IERC721A.sol";
import { IAccessControl } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import "src/internal/LeveragedStrategy.sol";
import "src/internal/PositionLedger.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract ExpirationTest is BaseTest {
    using ErrorsLeverageEngine for *;

    address public positionReceiver = makeAddr("receiver");

    function setUp() public {
        initFork();
        initTestFramework();

        deal(WBTC, address(allContracts.wbtcVault), 100e8);

        allContracts.positionExpirator.setMonitor(address(this));
    }

    // Helper function to update strategy config
    function updateStrategyConfig(uint256 newBlockNumber) internal {
        LeveragedStrategy.StrategyConfig memory strategyConfig =
            allContracts.leveragedStrategy.getStrategyConfig(ETHPLUSETH_STRATEGY);
        strategyConfig.positionLifetime = newBlockNumber;
        allContracts.leveragedStrategy.setStrategyConfig(ETHPLUSETH_STRATEGY, strategyConfig);
    }

    // Helper function to open an ETH-based position
    function openEthPosition() internal returns (uint256) {
        return openETHBasedPosition(10e8, 1e8);
    }

    // Helper function for expectRevert and expire position
    function expectRevertAndExpire(uint256 nftID, bytes4 selector) internal {
        ClosePositionParams memory params = getClosePositionParams(nftID);
        vm.expectRevert(selector);
        allContracts.positionExpirator.expirePosition(nftID, params);
    }

    function getClosePositionParams(uint256 nftID) internal view returns (ClosePositionParams memory) {
        bytes memory payloadClose = getWETHWBTCUniswapPayload();
        return ClosePositionParams({
            nftId: nftID,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payloadClose,
            exchange: address(0)
        });
    }

    function testSetExpirationBlock() public {
        uint256 newBlockNumber =
            allContracts.leveragedStrategy.getStrategyConfig(ETHPLUSETH_STRATEGY).positionLifetime + 10;
        updateStrategyConfig(newBlockNumber);

        LeveragedStrategy.StrategyConfig memory strategyConfigAfter =
            allContracts.leveragedStrategy.getStrategyConfig(ETHPLUSETH_STRATEGY);

        assert(strategyConfigAfter.positionLifetime == newBlockNumber);
    }

    function testChangeExpirationBlockDontAffectLivePositions() public {
        uint256 nftId = openEthPosition();
        uint256 expirationBlockBefore = allContracts.positionLedger.getExpirationBlock(nftId);

        uint256 newBlockNumber =
            allContracts.leveragedStrategy.getStrategyConfig(ETHPLUSETH_STRATEGY).positionLifetime + 10;
        updateStrategyConfig(newBlockNumber);

        uint256 expirationBlockAfter = allContracts.positionLedger.getExpirationBlock(nftId);

        assert(expirationBlockBefore == expirationBlockAfter);
    }

    function testPositionCanBeExpired() public {
        uint256 nftID = openEthPosition();
        bool isEligibleForExpiration = allContracts.positionLedger.isPositionEligibleForExpiration(nftID);
        assertEq(isEligibleForExpiration, false);

        uint256 expirationBlock = allContracts.positionLedger.getExpirationBlock(nftID);
        vm.roll(expirationBlock + 1);

        isEligibleForExpiration = allContracts.positionLedger.isPositionEligibleForExpiration(nftID);
        assertEq(isEligibleForExpiration, true);
    }

    function testCantExpireNotEligiblePosition() public {
        uint256 nftID = openEthPosition();
        expectRevertAndExpire(nftID, ErrorsLeverageEngine.NotEligibleForExpiration.selector);
    }

    function testCantExpireClosedPosition() public {
        uint256 nftID = openEthPosition();
        closeETHBasedPosition(nftID);
        expectRevertAndExpire(nftID, ErrorsLeverageEngine.PositionNotLive.selector);
    }

    function testCantExpireNotFromMonitor() public {
        uint256 nftID = openEthPosition();
        vm.prank(address(0));

        ClosePositionParams memory params = getClosePositionParams(nftID);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, 0, ProtocolRoles.MONITOR_ROLE));
        allContracts.positionExpirator.expirePosition(nftID, params);
    }

    function testPositionStateExpiredAfterExpiration() public {
        uint256 nftID = openEthPosition();
        uint256 expirationBlock = allContracts.positionLedger.getExpirationBlock(nftID);
        vm.roll(expirationBlock + 1);

        ClosePositionParams memory params = getClosePositionParams(nftID);
        allContracts.positionExpirator.expirePosition(nftID, params);

        PositionState state = allContracts.positionLedger.getPositionState(nftID);
        assert(state == PositionState.EXPIRED);
    }

    function testPositionUnwindOnExpiration() public {
        uint256 nftID = openEthPosition();
        uint256 expirationBlock = allContracts.positionLedger.getExpirationBlock(nftID);
        vm.roll(expirationBlock + 1);

        uint256 wbtcBalanceBefore = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));

        ClosePositionParams memory params = getClosePositionParams(nftID);
        allContracts.positionExpirator.expirePosition(nftID, params);

        uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));
        assert(wbtcBalanceAfter > wbtcBalanceBefore);
    }
}
