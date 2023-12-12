// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { ISwapAdapter } from "src/interfaces/ISwapAdapter.sol";
import { ISwapRouterUniV3 } from "src/interfaces/ISwapRouterUniV3.sol";
import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";


//TODO: Implement swap on different exchanges such as curvev2 pools and balancer
contract UniV3SwapAdapter is ISwapAdapter, AccessControlUpgradeable {

    using ProtocolRoles for *;

    IERC20 internal constant wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address internal constant UNISWAPV3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    
     struct UniswapV3Data {
        bytes path;
        uint256 deadline;
    }

    constructor() {
    }

    // NOTICE: Assumes WBTC already sent to this contract
    function swapToWbtc(SwapWbtcParams calldata params) 
        external 
        returns (uint256)
    {
        
        uint256 balanceBefore = wbtc.balanceOf(params.recipient);

        swapOnUniswapV3(params.otherToken, params.fromAmount, params.payload, params.recipient);

        return wbtc.balanceOf(params.recipient) - balanceBefore;
    }

    // NOTICE: Assumes tokens already sent to this contract
    function swapFromWbtc(SwapWbtcParams calldata params) 
        external 
        returns (uint256) 
    {
        uint256 balanceBefore = params.otherToken.balanceOf(params.recipient);

        swapOnUniswapV3(wbtc, params.fromAmount, params.payload, params.recipient);     

        return params.otherToken.balanceOf(params.recipient) - balanceBefore;
    }

    function swapOnUniswapV3(
        IERC20 fromToken,
        uint256 fromAmount,
        bytes calldata payload,
        address recipient
    )
        internal
    {
        UniswapV3Data memory data = abi.decode(payload, (UniswapV3Data));

        fromToken.approve(UNISWAPV3_ROUTER, fromAmount);
        ISwapRouterUniV3(UNISWAPV3_ROUTER).exactInput(
            ISwapRouterUniV3.ExactInputParams({
                path: data.path,
                recipient: recipient,
                deadline: data.deadline,
                amountIn: fromAmount,
                amountOutMinimum: 1
            })
        );
    }
}
