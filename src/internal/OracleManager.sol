// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "src/interfaces/IERC20Detailed.sol";

import { IOracle } from "src/interfaces/IOracle.sol";

import { ProtocolRoles } from "src/libs/ProtocolRoles.sol";
import { DependencyAddresses } from "src/libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "src/libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "src/libs/EventsLeverageEngine.sol";

/// @title OracleManager Contract
/// @notice Manages oracles for token pricing in the Leverage Engine system.
contract OracleManager is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    mapping(address => IOracle) internal ethOracles;
    mapping(address => IOracle) internal usdOracles;

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

    function setETHOracle(address token, IOracle oracle) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        ethOracles[token] = oracle;
        emit EventsLeverageEngine.ETHOracleSet(token, oracle);
    }

    function setUSDOracle(address token, IOracle oracle) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        usdOracles[token] = oracle;
        emit EventsLeverageEngine.USDOracleSet(token, oracle);
    }

    function getLatestTokenPriceInETH(address token) external view returns (uint256) {
        IOracle oracle = ethOracles[token];

        return oracle.getLatestPrice();
    }

    function getETHOracleDecimals(address token) external view returns (uint8) {
        IOracle oracle = ethOracles[token];
        return oracle.decimals();
    }

    function getLatestTokenPriceInUSD(address token) external view returns (uint256) {
        IOracle oracle = usdOracles[token];

        return oracle.getLatestPrice();
    }

    function getUSDOracleDecimals(address token) external view returns (uint8) {
        IOracle oracle = usdOracles[token];
        return oracle.decimals();
    }
}
