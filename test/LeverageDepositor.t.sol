// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import "openzeppelin-contracts/access/AccessControl.sol";

import "test/BaseTest.sol";
import { PositionLedger } from "src/PositionLedger.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract LeverageDepositorTest is BaseTest {
    /* solhint-disable  */

    using ErrorsLeverageEngine for *;

    function setUp() public virtual {
        initFork();
        initTestFramework();
        deal(WBTC, address(allContracts.wbtcVault), 1000e8);
    }

    function testOpenPositionStoreSharesOnDepositorContract() external {
        uint256 collateralAmount = 5e8;
        uint256 wbtcToBorrow = collateralAmount * 2;
       
        uint256 nftId = openETHBasedPosition(collateralAmount, wbtcToBorrow);

        address strategy = allContracts.positionLedger.getStrategyAddress(nftId);
        uint256 shareBalanceOnLeverageDepositorContract = ERC20(strategy).balanceOf(address(allContracts.leverageDepositor));

        uint256 shareCountReportedByLedger = allContracts.positionLedger.getStrategyShares(nftId);

        assertEq(shareBalanceOnLeverageDepositorContract, shareCountReportedByLedger);
    }

    function testClosePositionGetsSharesFromDepositorContract() external {

        uint256 collateralAmount = 5e8;
        uint256 wbtcToBorrow = collateralAmount * 2;
       
        uint256 nftId = openETHBasedPosition(collateralAmount, wbtcToBorrow);

        address strategy = allContracts.positionLedger.getStrategyAddress(nftId);
        uint256 shareBalanceOnLeverageDepositorContract = ERC20(strategy).balanceOf(address(allContracts.leverageDepositor));
        assertGt(shareBalanceOnLeverageDepositorContract, 0);

        closeETHBasedPosition(nftId);

        shareBalanceOnLeverageDepositorContract = ERC20(strategy).balanceOf(address(allContracts.leverageDepositor));
        assertEq(shareBalanceOnLeverageDepositorContract, 0);
    }

    function testLeverageDepoistorNonAdminCannotAllowStrategy() external {
        
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, 0, ProtocolRoles.ADMIN_ROLE));
        allContracts.leverageDepositor.allowStrategyWithDepositor(ETHPLUSETH_STRATEGY);
    }

      function testLeverageDepoistorNonAdminCannotDenyStrategy() external {
        
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, 0, ProtocolRoles.ADMIN_ROLE));
        allContracts.leverageDepositor.denyStrategyWithDepositor(ETHPLUSETH_STRATEGY);
    }

    function testCannotDepositAfterDenyingStrategy() external {

        allContracts.leverageDepositor.denyStrategyWithDepositor(ETHPLUSETH_STRATEGY);

        uint256 collateralAmount = 5e8;
        uint256 borrowAmount = collateralAmount * 2;

        deal(WBTC, address(this), collateralAmount);
        ERC20(WBTC).approve(address(allContracts.positionOpener), type(uint256).max);

        bytes memory payload = getWBTCWETHUniswapPayload(); 

        PositionOpener.OpenPositionParams memory params = PositionOpener.OpenPositionParams({
            collateralAmount: collateralAmount,
            wbtcToBorrow: borrowAmount,
            minStrategyShares: 0,
            strategy: ETHPLUSETH_STRATEGY,
            swapRoute: SwapManager.SwapRoute.UNISWAPV3,
            swapData: payload,
            exchange: address(0)
        });
    
        vm.expectRevert("SafeERC20: low-level call failed");
        allContracts.positionOpener.openPosition(params);
    }

}
