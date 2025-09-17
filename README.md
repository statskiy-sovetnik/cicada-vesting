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
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```
