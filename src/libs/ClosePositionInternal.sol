// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "src/interfaces/IERC20Detailed.sol";
import { ILeverageDepositor } from "src/interfaces/ILeverageDepositor.sol";
import { PositionLedger } from "src/PositionLedger.sol";
import { ClosePositionParams } from "src/libs/PositionCallParams.sol";
import { LeveragedStrategy } from "src/LeveragedStrategy.sol";
import { SwapManager } from "src/SwapManager.sol";
import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";




contract ClosePositionInternal {

    using ProtocolRoles for *;


    PositionLedger internal positionLedger;
    ILeverageDepositor internal leverageDepositor;
    LeveragedStrategy internal leveragedStrategy;
    SwapManager internal swapManager;

    function setDependenciesInternal(DependencyAddresses calldata dependencies) internal  {
        
        positionLedger = PositionLedger(dependencies.positionLedger);
    }  

    function unwindPosition(uint256 nftId) internal returns (uint256) {

        address strategyAddress = positionLedger.getStrategyAddress(nftId);
        uint256 strategyShares = positionLedger.getStrategyShares(nftId);

        return leverageDepositor.redeem(strategyAddress, strategyShares);
    }

    function swapStrategyTokenToWbtc(uint256 strategyTokenAmount, ClosePositionParams calldata params) internal returns (uint256) {

        address strategyAddress = positionLedger.getStrategyAddress(params.nftId);
        address strategyUnderlyingToken = leveragedStrategy.getStrategyValueAsset(strategyAddress); 
        ISwapAdapter swapAdapter = swapManager.getSwapAdapterForRoute(params.swapRoute);

        ISwapAdapter.SwapWbtcParams memory swapParams = ISwapAdapter.SwapWbtcParams({
            otherToken: IERC20(strategyUnderlyingToken),
            fromAmount: strategyTokenAmount,
            payload: params.swapData,
            recipient: address(this)
        });
      
        IERC20(strategyUnderlyingToken).transfer(address(swapAdapter), strategyTokenAmount); 
        return swapAdapter.swapToWbtc(swapParams);
    }
}