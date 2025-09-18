## Usage

### Build

```shell
$ npm run build
```
Or optimized:
```shell
$ npm run build:optimized
```

### Test

```shell
$ forge test
```
Running specific tests:
```shell
$ forge test --match-path "**/integration/concrete/lockup-base/**"
```

### Deploy

The script will prompt you to enter the deployer's private key.

```shell
$ forge script --chain <CHAIN> script/DeployLockup.s.sol --rpc-url <RPC> --broadcast --verify -vvvv --interactives 1
```

Deploying on Duckchain:
```shell
$ forge script --chain 5545 script/DeployLockup.s.sol --rpc-url https://rpc.duckchain.io --broadcast -vvvv --interactives 1
```
