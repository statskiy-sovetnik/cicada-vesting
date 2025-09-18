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

```shell
$ forge create src/SablierLockup.sol:SablierLockup --rpc-url <YOUR_RPC_URL> \
    --private-key <YOUR_PRIVATE_KEY> \
    --broadcast \
    --constructor-args "initialAdmin" "maxCount" 0x0000000000000000000000000000000000000000 500 \
    --etherscan-api-key <YOUR_ETHERSCAN_API_KEY> \
    --verify \
```
