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

    function test_ShouldRevertWithArithmeticOverflow() external {
        vm.expectRevert();
        leverageEngine.openPosition(5e18, 5e18, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, "", address(0));
    }

    function test_ShouldRevertWithExceedBorrowLimit() external {
        vm.expectRevert(LeverageEngine.ExceedBorrowLimit.selector);
        leverageEngine.openPosition(5e8, 80e8, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, "", address(0));
    }

    function test_ShouldAbleToOpenPosForWETHStrat() external {
        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(leverageEngine), 10e8);

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(3000), WETH),
                deadline: block.timestamp + 1000
            })
        );
        leverageEngine.openPosition(
            5e8, 15e8, ETHPLUSETH_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
        PositionLedgerLib.LedgerEntry memory position = leverageEngine.getPosition(0);
        assertEq(position.collateralAmount, 5e8);
        assertEq(position.wbtcDebtAmount, 15e8);
    }

    function test_ShouldAbleToOpenPosForUSDCStrat() external {
        deal(WBTC, address(this), 10e8);
        ERC20(WBTC).approve(address(leverageEngine), 10e8);

        bytes memory payload = abi.encode(
            SwapAdapter.UniswapV3Data({
                path: abi.encodePacked(WBTC, uint24(500), WETH, uint24(3000), USDC),
                deadline: block.timestamp + 1000
            })
        );
        leverageEngine.openPosition(
            5e8, 15e8, FRAXBPALUSD_STRATEGY, 0, SwapAdapter.SwapRoute.UNISWAPV3, payload, address(0)
        );
        PositionLedgerLib.LedgerEntry memory position = leverageEngine.getPosition(0);
        assertEq(position.collateralAmount, 5e8);
        assertEq(position.wbtcDebtAmount, 15e8);
    }

    function test_oracleCalculationWETH() external {
        uint256 wbtcAmount = 10 * 1e8;
        OracleTestHelper oracleTestHelper = new OracleTestHelper();
        bytes memory initData = abi.encodeWithSelector(
            LeverageEngine.initialize.selector,
            address(wbtcVault),
            address(leverageDepositor),
            address(positionToken),
            address(swapAdapter),
            address(feeCollector)
        );
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(oracleTestHelper), address(this), initData);
        oracleTestHelper = OracleTestHelper(address(proxy));
        oracleTestHelper.setOracle(WBTC, new ChainlinkOracle(WBTCUSDORACLE));
        oracleTestHelper.setOracle(WETH, new ChainlinkOracle(ETHUSDORACLE));

        AggregatorV3Interface wbtcOracle = AggregatorV3Interface(WBTCUSDORACLE);
        (, int256 wbtcPrice,,,) = wbtcOracle.latestRoundData();
        AggregatorV3Interface ethOracle = AggregatorV3Interface(ETHUSDORACLE);
        (, int256 ethPrice,,,) = ethOracle.latestRoundData();

        uint256 expected = (wbtcAmount * uint256(wbtcPrice) * 1e10) / uint256(ethPrice);
       
        assertEq(oracleTestHelper.checkOracles(WETH, wbtcAmount), expected);
    }

    function test_oracleCalculationUSDC() external {
        uint256 wbtcAmount = 10 * 1e8;
        OracleTestHelper oracleTestHelper = new OracleTestHelper();
        bytes memory initData = abi.encodeWithSelector(
            LeverageEngine.initialize.selector,
            address(wbtcVault),
            address(leverageDepositor),
            address(positionToken),
            address(swapAdapter),
            address(feeCollector)
        );
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(oracleTestHelper), address(this), initData);
        oracleTestHelper = OracleTestHelper(address(proxy));
        oracleTestHelper.setOracle(WBTC, new ChainlinkOracle(WBTCUSDORACLE));
        oracleTestHelper.setOracle(USDC, new ChainlinkOracle(USDCUSDORACLE));

        AggregatorV3Interface wbtcOracle = AggregatorV3Interface(WBTCUSDORACLE);
        (, int256 wbtcPrice,,,) = wbtcOracle.latestRoundData();
        AggregatorV3Interface usdcOracle = AggregatorV3Interface(USDCUSDORACLE);
        (, int256 usdcPrice,,,) = usdcOracle.latestRoundData();

        uint256 expected = (wbtcAmount * uint256(wbtcPrice)) / (uint256(usdcPrice) * 1e2);
      
        assertEq(oracleTestHelper.checkOracles(USDC, wbtcAmount), expected);
    }
}
