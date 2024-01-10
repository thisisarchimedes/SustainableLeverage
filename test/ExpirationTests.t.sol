// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import "test/BaseTest.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { IERC721A } from "ERC721A/IERC721A.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import "src/internal/LeveragedStrategy.sol";
import "src/internal/PositionLedger.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract ExpirationTest is BaseTest {
    using ErrorsLeverageEngine for *;

    /* solhint-disable  */
    address positionReceiver = makeAddr("receiver");

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        initFork();
        initTestFramework();

        deal(WBTC, address(allContracts.wbtcVault), 100e8);

        allContracts.positionExpirator.setMonitor(address(this));
    }

    function testSetExpirationBlock() public {
        // get the startegy
        LeveragedStrategy.StrategyConfig memory strategyConfigBefore =
            allContracts.leveragedStrategy.getStrategyConfig(ETHPLUSETH_STRATEGY);

        // call set setStrategyConfig with a future block
        uint256 newBlockNumber = strategyConfigBefore.positionLifetime + 10;

        allContracts.leveragedStrategy.setStrategyConfig(
            ETHPLUSETH_STRATEGY,
            LeveragedStrategy.StrategyConfig({
                quota: strategyConfigBefore.quota,
                positionLifetime: newBlockNumber,
                maximumMultiplier: strategyConfigBefore.maximumMultiplier,
                liquidationBuffer: strategyConfigBefore.liquidationBuffer,
                liquidationFee: strategyConfigBefore.liquidationFee
            })
        );

        //check expiration == future block
        LeveragedStrategy.StrategyConfig memory strategyConfigAfter =
            allContracts.leveragedStrategy.getStrategyConfig(ETHPLUSETH_STRATEGY);

        assert(strategyConfigAfter.positionLifetime == newBlockNumber);
    }

    function testChangeExpirationBlockDontAffectLivePositions() public {
        uint256 nftId = openETHBasedPosition(10e8, 1e8);

        uint256 expirationBlockBefore = allContracts.positionLedger.getExpirationBlock(nftId);

        LeveragedStrategy.StrategyConfig memory strategyConfigBefore =
            allContracts.leveragedStrategy.getStrategyConfig(ETHPLUSETH_STRATEGY);

        // call set setStrategyConfig with a future block
        uint256 newBlockNumber = strategyConfigBefore.positionLifetime + 10;

        allContracts.leveragedStrategy.setStrategyConfig(
            ETHPLUSETH_STRATEGY,
            LeveragedStrategy.StrategyConfig({
                quota: strategyConfigBefore.quota,
                positionLifetime: newBlockNumber,
                maximumMultiplier: strategyConfigBefore.maximumMultiplier,
                liquidationBuffer: strategyConfigBefore.liquidationBuffer,
                liquidationFee: strategyConfigBefore.liquidationFee
            })
        );

        uint256 expirationBlockAfter = allContracts.positionLedger.getExpirationBlock(nftId);

        assert(expirationBlockBefore == expirationBlockAfter);
    }

    function testPositionCanBeExpired() public {
        uint256 nftID = openETHBasedPosition(10e8, 1e8);
        bool isEligibleForExpiration = allContracts.positionLedger.isPositionEligibleForExpiration(nftID);
        assertEq(isEligibleForExpiration, false);

        // run forward to a future block
        uint256 expirationBlock = allContracts.positionLedger.getExpirationBlock(nftID);
        vm.roll(expirationBlock + 1);

        isEligibleForExpiration = allContracts.positionLedger.isPositionEligibleForExpiration(nftID);
        assertEq(isEligibleForExpiration, true);
    }

    function testCantExpireNotEligiblePosition() public {
        // create a position
        uint256 nftID = openETHBasedPosition(10e8, 1e8);

        //catch a revert
        vm.expectRevert(ErrorsLeverageEngine.NotEligibleForExpiration.selector);

        bytes memory payloadClose = getWETHWBTCUniswapPayload();

        ClosePositionParams memory params = ClosePositionParams({
            nftId: nftID,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payloadClose,
            exchange: address(0)
        });

        //try to expire
        allContracts.positionExpirator.expirePosition(nftID, params);
    }

    function testCantExpireClosedPosition() public {
        uint256 nftID = openETHBasedPosition(10e8, 1e8);

        closeETHBasedPosition(nftID);

        //catch a revert
        vm.expectRevert(ErrorsLeverageEngine.PositionNotLive.selector);

        bytes memory payloadClose = getWETHWBTCUniswapPayload();

        ClosePositionParams memory params = ClosePositionParams({
            nftId: nftID,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payloadClose,
            exchange: address(0)
        });

        //try to expire
        allContracts.positionExpirator.expirePosition(nftID, params);
    }

    function testCantExpireNotFromMonitor() public {
        uint256 nftID = openETHBasedPosition(10e8, 1e8);

        vm.prank(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, 0, ProtocolRoles.MONITOR_ROLE
            )
        );

        bytes memory payloadClose = getWETHWBTCUniswapPayload();

        ClosePositionParams memory params = ClosePositionParams({
            nftId: nftID,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payloadClose,
            exchange: address(0)
        });

        allContracts.positionExpirator.expirePosition(nftID, params);
    }

    function testPositionStateExpiredAfterExpiration() public {
        uint256 nftID = openETHBasedPosition(10e8, 1e8);

        // run forward to a future block
        uint256 expirationBlock = allContracts.positionLedger.getExpirationBlock(nftID);
        vm.roll(expirationBlock + 1);

        bytes memory payloadClose = getWETHWBTCUniswapPayload();

        ClosePositionParams memory params = ClosePositionParams({
            nftId: nftID,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payloadClose,
            exchange: address(0)
        });

        //try to expire
        allContracts.positionExpirator.expirePosition(nftID, params);

        //get position state
        PositionState state = allContracts.positionLedger.getPositionState(nftID);

        assert(state == PositionState.EXPIRED);
    }

    function testPositionUnwindOnExpiration() public {
        uint256 nftID = openETHBasedPosition(10e8, 1e8);

        // run forward to a future block
        uint256 expirationBlock = allContracts.positionLedger.getExpirationBlock(nftID);
        vm.roll(expirationBlock + 1);

        //get vault balance
        uint256 wbtcBalanceBefore = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));

        bytes memory payloadClose = getWETHWBTCUniswapPayload();

        ClosePositionParams memory params = ClosePositionParams({
            nftId: nftID,
            minWBTC: 0,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payloadClose,
            exchange: address(0)
        });

        //try to expire
        allContracts.positionExpirator.expirePosition(nftID, params);

        //get vault balance
        uint256 wbtcBalanceAfter = IERC20(WBTC).balanceOf(address(allContracts.wbtcVault));

        assert(wbtcBalanceAfter > wbtcBalanceBefore);
    }
}
