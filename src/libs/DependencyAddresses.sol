// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

struct DependencyAddresses {
    address leverageEngine;
    address expiredVault;
    address leverageDepositor;
    address positionToken;
    address wbtcVault;
    address proxyAdmin;
    address swapAdapter;
    address leveragedStrategy;
    address protocolParameters;
    address oracleManager;
    address positionOpener;
    address positionCloser;
    address positionLedger;
}
