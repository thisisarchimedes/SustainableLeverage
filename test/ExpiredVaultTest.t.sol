// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
import { ExpiredVault } from "../src/ExpiredVault.sol";
import { IERC721A } from "ERC721A/IERC721A.sol";
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
    }

    function testDeposit() public {
        vm.startPrank(address(leverageEngine));

        // Arrange
        uint256 depositAmount = 1e18; // 1 WBTC for simplicity

        // Act
        deal(address(expiredVault.wbtc()), address(leverageEngine), 100e8); // TODO: remove?
        expiredVault.wbtc().safeTransfer(address(this), depositAmount);
        // expiredVault.wbtc().approve(address(expiredVault), depositAmount);
        // expiredVault.wbtc().safeTransferFrom(address(leverageEngine), address(expiredVault), depositAmount);
        // expiredVault.deposit(depositAmount);

        // Assert
        // assertEq(expiredVault.balance(), depositAmount, "Vault balance should be updated");
    }


    function testFailDepositNotMonitor() public {
        // This test will pass if it reverts (as indicated by the prefix 'testFail')
        uint256 depositAmount = 1e18; // 1 WBTC for simplicity

        // Act
        expiredVault.deposit(depositAmount); // This should fail because 'user' is not in MONITOR_ROLE
    }

    function testClaimInsufficientFunds() public {
        // Arrange
        _openPosition();
        uint256 nftID = 0; // Example NFT ID

        // TODO: leverageEngine.expirePosition(nftID);

        // Act & Assert
        vm.expectRevert(ExpiredVault.InsufficientFunds.selector);
        expiredVault.claim(nftID);
    }

    function testClaim() public {
        // Arrange
        _openPosition();
        uint256 nftID = 0; // Example NFT ID
        uint256 claimableAmount = 1e8; // 1 WBTC for simplicity

        // TODO: leverageEngine.expirePosition(nftID);

        // Act
        expiredVault.claim(nftID);

        // Assert
        PositionLedgerLib.LedgerEntry memory position = leverageEngine.getPosition(nftID);
        assertEq(position.claimableAmount, 0, "Position claimableAmount should be 0");
        assertTrue(position.state == PositionLedgerLib.PositionState.CLOSED, "Position state should be CLOSED");
        assertEq(expiredVault.balance(), 0, "Expired vault balance should be 0");
        assertEq(wbtc.balanceOf(address(this)), claimableAmount, "WBTC balance should be updated");
        assertEq(leverageEngine.nft().ownerOf(nftID), address(0), "NFT should be burned");
    }

    function testClaimNonExistingNftId() public {
        uint256 nonExistingNftID = 999; // An NFT ID that doesn't exist

        // Expect a revert
        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        expiredVault.claim(nonExistingNftID);
    }

    function testClaimPositionNotExpired() public {
        // Arrange
        _openPosition();
        uint256 nftID = 0; // Example NFT ID

        vm.startPrank(address(leverageEngine));
        expiredVault.deposit(1e8);
        vm.stopPrank();

        vm.expectRevert(LeverageEngine.PositionNotExpired.selector);
        expiredVault.claim(nftID);
    }

    function testClaimPositionOwnedByAnotherUser() public {
        // Arrange
        _openPosition();
        uint256 nftID = 0; // Example NFT ID

        vm.startPrank(address(leverageEngine));
        expiredVault.deposit(1e8);
        vm.stopPrank();

        vm.startPrank(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));

        vm.expectRevert(LeverageEngine.NotOwner.selector);
        expiredVault.claim(nftID);
    }

    ///////////// Helper functions /////////////

    function _openPosition() internal {
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );
        leverageEngine.openPosition(
            5e8, 15e8, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
    }
}
