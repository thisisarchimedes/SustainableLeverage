// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import "./BaseTest.sol";
import "./helpers/OracleTestHelper.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests

contract OpenPositionTest is BaseTest {
    /* solhint-disable  */
    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 18_369_197 });
        _prepareContracts();
        deal(WBTC, address(wbtcVault), 100e8);
    }

    // TODO: tommorrow keep working on this test, generalize it to auto deal with tokens with different decimals
    // test and implement a generalized method we can use in production
    function testLearningGetWBTCPriceForUnderlyingToken() external {

        address oracleETHUSD = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        address oracleBTCUSD = address(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);

        ERC20 wbtc = ERC20(WBTC);  
        ERC20 weth = ERC20(WETH); 

        uint wbtcDecimals = 8;
        uint256 oracleDecimals = 8;
        
        uint256 targetTokenDecimals = IERC20Detailed(WBTC).decimals();
        
        (, int256 priceETHUSD,,,) = AggregatorV3Interface(oracleETHUSD).latestRoundData();
        (, int256 priceBTCUSD,,,) = AggregatorV3Interface(oracleBTCUSD).latestRoundData();

        // how much WTBC for 1000 ETH?
        uint256 wethAmount = 1000e18;
        uint256 wbtcAmount = wethAmount * uint256(priceETHUSD) 
                /( uint256(priceBTCUSD) * 10**(18-wbtcDecimals));


        console2.log("ethAmount:", wethAmount);
        console2.log("wbtcAmount:", wbtcAmount); 

    }
/*
    function testPositionIsEligableForLiquidation() {
            _openPosition();
            bool isEligibleForLiquidation = leverageEngine.isPostionEligibleForLiquidation();

            assertEq(isEligibleForLiquidation , false);

    }

    function _openPosition() internal {
         deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(leverageEngine), 10e8);
        leverageEngine.setStrategyConfig(ETHPLUSETH_STRATEGY, 100e8, 1000, 3e8, 1.25e8);
        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );
        leverageEngine.openPosition(
            5e8, 15e8, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
    }*/

}