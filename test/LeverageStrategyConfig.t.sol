// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import "test/BaseTest.sol";

contract LeverageStrategyConfig is BaseTest {
    /* solhint-disable  */

    function setUp() public virtual {
        initFork();
        initTestFramework();
    }

    function test_MaxMultiplierIsGreaterThanOne() external {

        // quick check that we initialized the test suit correctly

        uint256 multiplier1 = allContracts.leveragedStrategy.getMaximumMultiplier(ETHPLUSETH_STRATEGY);
        assertGt(multiplier1, 1);

        uint256 multiplier2 = allContracts.leveragedStrategy.getMaximumMultiplier(FRAXBPALUSD_STRATEGY);
        assertGt(multiplier2, 1);
    }

    function test_LiquidationBufferIsGreaterThanOne() external {

        // quick check that we initialized the test suit correctly

        uint256 buffer1 = allContracts.leveragedStrategy.getLiquidationBuffer(ETHPLUSETH_STRATEGY);
        assertGt(buffer1, 1);

        uint256 buffer2 = allContracts.leveragedStrategy.getLiquidationBuffer(FRAXBPALUSD_STRATEGY);
        assertGt(buffer2, 1);
    }
}
