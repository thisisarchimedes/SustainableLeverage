# SustainableLeverage [![CI](https://github.com/thisisarchimedes/SustainableLeverage/actions/workflows/ci.yml/badge.svg)](https://github.com/thisisarchimedes/SustainableLeverage/actions/workflows/ci.yml)

Sustainable Leverage v2

## Quick start

### Build

Build the contracts:

```sh
$ forge build
```

### Deploy

Deploy to Anvil:

```sh
$ forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545 --slow
```

### Test

Run the tests:

```sh
$ forge test
```

### Custom Scripts

Open Position (fork):

```sh
$ forge script script/OpenPosition.s.sol --broadcast --fork-url http://ec2-52-4-114-208.compute-1.amazonaws.com:8545 --slow
```

### CICD

1. Open a PR request, Github Actionswill run Linter and Tests
2. If test pass and PR reviewed, merge it to main
3. While merging Github Actions will updated the contract addresses in `deployments/` directory
