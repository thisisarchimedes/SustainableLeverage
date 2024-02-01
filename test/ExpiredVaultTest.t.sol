// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

// solhint-disable-next-line no-global-import
import "./BaseTest.sol";

import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";


contract ExpiredVaultTest is BaseTest {
    using ErrorsLeverageEngine for *;

    function setUp() public {
        initFork();
        initTestFramework();

        deal(WBTC, address(allContracts.wbtcVault), 100e8);
        ERC20(WBTC).approve(address(allContracts.positionOpener), type(uint256).max);
        ERC20(WBTC).approve(address(allContracts.positionCloser), type(uint256).max);
    }

    function testDeposit() public {
        vm.startPrank(address(allContracts.positionLiquidator));

        // Arrange
        uint256 depositAmount = 1e8; // 1 WBTC for simplicity

        // Act
        deal(address(wbtc), address(allContracts.positionLiquidator), 100e8);
        allContracts.expiredVault.deposit(depositAmount);

        // Assert
        assertEq(allContracts.expiredVault.balance(), depositAmount, "Vault balance should be updated");
    }

    function testDepositNotMonitor() public {
        uint256 depositAmount = 1e8; // 1 WBTC for simplicity

        // Act
        vm.expectRevert();
        allContracts.expiredVault.deposit(depositAmount); // This should fail because 'user' is not in MONITOR_ROLE
    }

    function testClaim() public {
        // Arrange
        uint256 nftId = openETHBasedPosition(10e8, 30e8);

        // Liquidate the position
        liquidateETHPosition(nftId);
        uint256 claimableAmount = allContracts.positionLedger.getPosition(nftId).claimableAmount;

        // Act
        uint256 balanceBefore = wbtc.balanceOf(address(this));
        allContracts.expiredVault.claim(nftId);
        uint256 balanceAfter = wbtc.balanceOf(address(this));

        // Assert
        LedgerEntry memory position = allContracts.positionLedger.getPosition(nftId);
        assertEq(position.claimableAmount, 0, "Position claimableAmount should be 0");
        assertTrue(position.state == PositionState.CLOSED, "Position state should be CLOSED");
        assertEq(allContracts.expiredVault.balance(), 0, "Expired vault balance should be 0");
        assertEq(
            balanceAfter - balanceBefore,
            claimableAmount,
            "WBTC balance should be updated to the claimable position amount"
        );

        vm.expectRevert();
        allContracts.positionToken.ownerOf(nftId);
    }

    function testClaimNonExistingNftId() public {
        uint256 nonExistingNftID = 999; // An NFT ID that doesn't exist

        // Expect a revert

        vm.expectRevert();
        allContracts.expiredVault.claim(nonExistingNftID);
    }

    function testClaimPositionNotExpiredOrLiquidated() public {
        // Arrange
        uint256 nftId = openETHBasedPosition(10e8, 30e8);

        deal(WBTC, address(allContracts.positionLiquidator), 100e8);
        vm.startPrank(address(allContracts.positionLiquidator));
        allContracts.expiredVault.deposit(1e8);
        vm.stopPrank();

        vm.expectRevert(ErrorsLeverageEngine.PositionNotExpiredOrLiquidated.selector);
        allContracts.expiredVault.claim(nftId);
    }

    function testClaimPositionOwnedByAnotherUser() public {
        // Arrange
        uint256 nftId = openETHBasedPosition(10e8, 30e8);

        liquidateETHPosition(nftId);

        vm.startPrank(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));

        vm.expectRevert(ErrorsLeverageEngine.NotOwner.selector);
        allContracts.expiredVault.claim(nftId);
    }
}
