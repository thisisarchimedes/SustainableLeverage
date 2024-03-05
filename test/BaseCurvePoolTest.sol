// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21 <0.9.0;

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "test/BaseTest.sol";
import { ICurveStableswapFactoryNG } from "../src/interfaces/ICurveStableswapFactoryNG.sol";
import { ICurvePool } from "../src/interfaces/ICurvePool.sol";

abstract contract BaseCurvePoolTest is BaseTest {
    ICurveStableswapFactoryNG public poolManager = ICurveStableswapFactoryNG(CURVE_STABLE_FACTORY_NG);

    address public constant CURVE_STABLE_FACTORY_NG = 0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf;

    
}
