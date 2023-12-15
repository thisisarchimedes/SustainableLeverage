// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
import { console2 } from "forge-std/console2.sol";

import { ERC721 } from "openzeppelin-contracts/token/ERC721/ERC721.sol";

import { FakeWBTCWETHSwapAdapter } from "src/ports/swap_adapters/FakeWBTCWETHSwapAdapter.sol";
import { FakeOracle } from "src/ports/oracles/FakeOracle.sol";

import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";

import { ExpiredVault } from "src/user_facing/ExpiredVault.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract ExpiredVaultTest is BaseTest {
    using ErrorsLeverageEngine for *;

    /// @dev A function invoked before each test case is run.
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

    function testResetExpiredVault() external {
        /*
        TODO: Fix this test - probably shoud have set dependcy test for all contracts

        // Remember
        address oldExpiredVault = address(expiredVault);
        IERC20 wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

        // Prepare new expired vault
        ExpiredVault newExpiredVault = new ExpiredVault();
        bytes memory initDataExpiredVault =
            abi.encodeWithSelector(ExpiredVault.initialize.selector, address(leverageEngine), WBTC);
        newExpiredVault = ExpiredVault(
        address(new TransparentUpgradeableProxy(address(newExpiredVault),address(proxyAdmin),initDataExpiredVault))
        );

        // Reset
        leverageEngine.setExpiredVault(address(newExpiredVault));

        // Assert
        assertNotEq(
            leverageEngine.getCurrentExpiredVault(), address(oldExpiredVault), "Expired vault should be updated"
        );
        assertEq(leverageEngine.getCurrentExpiredVault(), address(newExpiredVault), "Expired vault should be updated");
        assertEq(
            wbtc.allowance(address(leverageEngine), address(oldExpiredVault)),
            0,
            "Old expired vault should be disapproved"
        );
        assertEq(
            wbtc.allowance(address(leverageEngine), address(newExpiredVault)),
            type(uint256).max,
            "Expired vault should be approved"
        );
        assertFalse(
            leverageEngine.hasRole(ProtocolRoles.EXPIRED_VAULT_ROLE, address(oldExpiredVault)),
            "Old expired vault should be removed from MONITOR_ROLE"
        );
        assertTrue(
            leverageEngine.hasRole(ProtocolRoles.EXPIRED_VAULT_ROLE, address(newExpiredVault)),
            "Expired vault should be added to MONITOR_ROLE"
        );*/
    }
}
