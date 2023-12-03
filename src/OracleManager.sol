// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IERC20Detailed.sol";
import { IOracle } from "./interfaces/IOracle.sol";
import { ProtocolRoles } from "./libs/ProtocolRoles.sol";
import { DependencyAddresses } from "./libs/DependencyAddresses.sol";
import { ErrorsLeverageEngine } from "./libs/ErrorsLeverageEngine.sol";
import { EventsLeverageEngine } from "./libs/EventsLeverageEngine.sol";


/// @title OracleManager Contract
/// @notice Manages oracles for token pricing in the Leverage Engine system.
contract OracleManager is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ProtocolRoles for *;
    using ErrorsLeverageEngine for *;
    using EventsLeverageEngine for *;

    mapping(address => IOracle) internal oracles;

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(ProtocolRoles.ADMIN_ROLE, msg.sender);
    }

      function setOracle(address token, IOracle oracle) external onlyRole(ProtocolRoles.ADMIN_ROLE) {
        oracles[token] = oracle;
        emit EventsLeverageEngine.OracleSet(token, oracle);
    }

    function getLatestPrice(address token) external view returns (uint256) {
        IOracle oracle = oracles[token];
        (, int256 price,,,) = oracle.latestRoundData();
        
        return uint256(price);
    }

    function getOracleDecimals(address token) external view returns (uint8) {
        IOracle oracle = oracles[token];
        return oracle.decimals();
    }
}
