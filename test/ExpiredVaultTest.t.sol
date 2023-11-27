// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
import { ExpiredVault } from "../src/ExpiredVault.sol";
import { IERC721A } from "ERC721A/IERC721A.sol";
import { FakeWBTCWETHSwapAdapter } from "../src/ports/FakeWBTCWETHSwapAdapter.sol";
import { FakeOracle } from "../src/ports/FakeOracle.sol";
import { console2 } from "forge-std/console2.sol";
/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract ExpiredVaultTest is BaseTest {
    using SafeERC20 for IERC20;

    /// @dev A function invoked before each test case is run.
    function setUp() public {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 18_369_197 });
        _prepareContracts();
        deal(WBTC, address(wbtcVault), 100e8);
        ERC20(WBTC).approve(address(leverageEngine), type(uint256).max);
    }

    function testDeposit() public {
        vm.startPrank(address(leverageEngine));

        // Arrange
        uint256 depositAmount = 1e8; // 1 WBTC for simplicity

        // Act
        deal(address(expiredVault.wbtc()), address(leverageEngine), 100e8);
        expiredVault.deposit(depositAmount);

        // Assert
        assertEq(expiredVault.balance(), depositAmount, "Vault balance should be updated");
    }


    function testDepositNotMonitor() public {
        uint256 depositAmount = 1e8; // 1 WBTC for simplicity

        // Act
        vm.expectRevert();
        expiredVault.deposit(depositAmount); // This should fail because 'user' is not in MONITOR_ROLE
    }

    function testClaim() public {
        // Arrange
        uint256 nftId = openETHBasedPosition(10e8, 30e8);

        // Liquidate the position
        liquidatePosition(nftId);
        uint256 claimableAmount = leverageEngine.getPosition(nftId).claimableAmount;

        // Act
        uint256 balanceBefore = wbtc.balanceOf(address(this));
        expiredVault.claim(nftId);
        uint256 balanceAfter = wbtc.balanceOf(address(this));

        // Assert
        PositionLedgerLib.LedgerEntry memory position = leverageEngine.getPosition(nftId);
        assertEq(position.claimableAmount, 0, "Position claimableAmount should be 0");
        assertTrue(position.state == PositionLedgerLib.PositionState.CLOSED, "Position state should be CLOSED");
        assertEq(expiredVault.balance(), 0, "Expired vault balance should be 0");
        assertEq(balanceAfter - balanceBefore, claimableAmount, "WBTC balance should be updated to the claimable position amount");
        
        PositionToken positionToken = PositionToken(leverageEngine.nft());
        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector); // NFT should be burned
        positionToken.ownerOf(nftId);
    }

    function testClaimNonExistingNftId() public {
        uint256 nonExistingNftID = 999; // An NFT ID that doesn't exist

        // Expect a revert
        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        expiredVault.claim(nonExistingNftID);
    }

    function testClaimPositionNotExpiredOrLiquidated() public {
        // Arrange
        uint256 nftId = openETHBasedPosition(10e8, 30e8);

        deal(WBTC, address(leverageEngine), 100e8);
        vm.startPrank(address(leverageEngine));
        expiredVault.deposit(1e8);
        vm.stopPrank();

        vm.expectRevert(LeverageEngine.PositionNotExpiredOrLiquidated.selector);
        expiredVault.claim(nftId);
    }

    function testClaimPositionOwnedByAnotherUser() public {
        // Arrange
        uint256 nftId = openETHBasedPosition(10e8, 30e8);

        liquidatePosition(nftId);

        vm.startPrank(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));

        vm.expectRevert(LeverageEngine.NotOwner.selector);
        expiredVault.claim(nftId);
    }


    function testResetExpiredVault() external {
        // Remember
        address oldExpiredVault = address(expiredVault);

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
        assertNotEq(leverageEngine.expiredVault(), address(oldExpiredVault), "Expired vault should be updated");
        assertEq(leverageEngine.expiredVault(), address(newExpiredVault), "Expired vault should be updated");
        assertEq(leverageEngine.wbtc().allowance(address(leverageEngine), address(oldExpiredVault)), 0, "Old expired vault should be disapproved");
        assertEq(leverageEngine.wbtc().allowance(address(leverageEngine), address(newExpiredVault)), type(uint256).max, "Expired vault should be approved");
        assertFalse(leverageEngine.hasRole(leverageEngine.EXPIRED_VAULT_ROLE(), address(oldExpiredVault)), "Old expired vault should be removed from MONITOR_ROLE");
        assertTrue(leverageEngine.hasRole(leverageEngine.EXPIRED_VAULT_ROLE(), address(newExpiredVault)), "Expired vault should be added to MONITOR_ROLE");
    }
}
