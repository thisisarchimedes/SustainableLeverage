// SPDX-License-Identifier: CC BY-NC-ND 4.0
pragma solidity >=0.8.21;

struct DependencyAddresses {
    address expiredVault;
    address leverageDepositor;
    address positionToken;
    address wbtcVault;
    address proxyAdmin;
    address leveragedStrategy;
    address protocolParameters;
    address oracleManager;
    address positionOpener;
    address positionCloser;
    address positionLiquidator;
    address positionExpirator;
    address positionLedger;
    address swapManager;
}
