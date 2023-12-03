// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./IERC20Detailed.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { IWBTCVault } from "./IWBTCVault.sol";
import { IOracle } from "./IOracle.sol";
import { ILeverageDepositor } from "./ILeverageDepositor.sol";
import { PositionToken } from "../PositionToken.sol";
import { SwapAdapter } from "../SwapAdapter.sol";
import { IMultiPoolStrategy } from "./IMultiPoolStrategy.sol";
import { AggregatorV3Interface } from "./AggregatorV3Interface.sol";

interface ILeverageEngine {

    ///////////// Admin functions /////////////

    function changeSwapAdapter(address _swapAdapter) external;

    ///////////// View functions /////////////

    function closePosition(
        uint256 nftID,
        uint256 minWBTC,
        SwapAdapter.SwapRoute swapRoute,
        bytes calldata swapData,
        address exchange
    )
        external;

    function closeExpiredOrLiquidatedPosition(uint256 nftID, address sender) external;

}
