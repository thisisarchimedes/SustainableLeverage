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
import { PositionToken } from "src/PositionToken.sol";
import { IWBTCVault } from "src/interfaces/IWBTCVault.sol";
import { ProtocolParameters } from "src/ProtocolParameters.sol";
import { OracleManager } from "src/OracleManager.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";


contract ClosePositionInternal {

    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    uint8 internal constant WBTC_DECIMALS = 8;
    IERC20 internal constant wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    PositionLedger internal positionLedger;
    ILeverageDepositor internal leverageDepositor;
    LeveragedStrategy internal leveragedStrategy;
    SwapManager internal swapManager;
    PositionToken internal positionToken;
    IWBTCVault internal wbtcVault;
    ProtocolParameters internal protocolParameters;
    OracleManager internal oracleManager;


    function setDependenciesInternal(DependencyAddresses calldata dependencies) internal  {
        
        positionLedger = PositionLedger(dependencies.positionLedger);
        positionToken = PositionToken(dependencies.positionToken);
        swapManager = SwapManager(dependencies.swapManager);
        
        wbtcVault = IWBTCVault(dependencies.wbtcVault);
        leveragedStrategy = LeveragedStrategy(dependencies.leveragedStrategy);
        protocolParameters = ProtocolParameters(dependencies.protocolParameters);
        
        oracleManager = OracleManager(dependencies.oracleManager);
        positionLedger = PositionLedger(dependencies.positionLedger);
        leverageDepositor = ILeverageDepositor(dependencies.leverageDepositor);
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