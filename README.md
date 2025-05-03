# OP-Sync-Read-L1

A demonstration of techniques for reading L1 state from L2 contracts in Optimism's ecosystem.

## Overview

This project explores two precompiled contracts in Optimism that enable L2 contracts to read data from L1:

1. **Remote Static Call (0x0101)** - Call any view/constant function on L1 contracts
2. **L1 SLOAD (0x0102)** - Directly read storage slots from L1 contracts

These techniques provide efficient ways to access L1 data from L2 without requiring message passing.

## Implementation

The core modifications to enable these precompiles are available in these repositories:

- [Optimism Monorepo Changes](https://github.com/ethereum-optimism/optimism/compare/develop...winor30:optimism:feat/remotestaticcall-l1sload?expand=1)
- [op-geth Changes](https://github.com/ethereum-optimism/op-geth/compare/optimism...winor30:op-geth:feat/remotestaticcall-l1sload?expand=1)

## Contracts

- `L1Counter.sol`: A simple counter contract deployed on L1
- `RemoteReader.sol`: L2 contract demonstrating both reading methods

## Usage

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Access to an Optimism development environment (like Kurtosis)
- Docker

### Setup Development Environment

#### Build Custom op-geth Image

```shell
# Build custom op-geth image with precompile implementations
cd ~/ghq/github.com/winor30/op-geth
docker build -t winor30/op-geth:remotestaticcall-l1sload .
```

#### Start Kurtosis Development Environment

```shell
# Start devnet with the custom configuration
cd ~/ghq/github.com/winor30/optimism/kurtosis-devnet
AUTOFIX=true just devnet remotestaticcall-l1sload.yaml
```

### Deploy & Test

```shell
# Set environment variables
export PRIV=0xac09...ff80  # dev-account-0 private key
export ADDR=0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
export L1_RPC=http://127.0.0.1:[PORT]
export L2_RPC=http://127.0.0.1:[PORT]

# Fund L1 account
cast send $ADDR --rpc-url $L1_RPC --private-key $FAUCET_PK --legacy --value 1ether

# Deploy L1 counter
forge create src/L1Counter.sol:L1Counter --rpc-url $L1_RPC --private-key $PRIV --legacy --broadcast --json > l1.json
export L1_ADDR=$(jq -r '.deployedTo' l1.json)

# Deploy L2 reader
forge create src/RemoteReader.sol:RemoteReader --rpc-url $L2_RPC --private-key $PRIV --legacy --broadcast --json > l2.json
export L2_ADDR=$(jq -r '.deployedTo' l2.json)

# Read L1 state using Remote Static Call
cast send $L2_ADDR "readCountRSC(address)" $L1_ADDR --rpc-url $L2_RPC --private-key $PRIV --legacy --gas-limit 500000

# Read L1 state using L1SLOAD
cast send $L2_ADDR "readCountL1SLOAD(address)" $L1_ADDR --rpc-url $L2_RPC --private-key $PRIV --legacy --gas-limit 500000

# Increment counter on L1
cast send $L1_ADDR "inc()" --rpc-url $L1_RPC --private-key $PRIV --legacy

# Verify L2 can read the updated state
cast send $L2_ADDR "readCountRSC(address)" $L1_ADDR --rpc-url $L2_RPC --private-key $PRIV --legacy --gas-limit 500000
cast send $L2_ADDR "readCountL1SLOAD(address)" $L1_ADDR --rpc-url $L2_RPC --private-key $PRIV --legacy --gas-limit 500000
```

## Implementation Details

### Remote Static Call (0x0101)

```solidity
address constant RSC = 0x0000000000000000000000000000000000000101;

function readCountRSC(address l1) external {
  bytes memory data = abi.encodeWithSelector(L1Counter.count.selector);
  (bool ok, bytes memory ret) = RSC.staticcall(abi.encode(l1, data));
  require(ok);
  emit ReadByRSC(abi.decode(ret, (uint))); 
}
```

This precompile forwards a static call to the L1 node, executing at a fixed L1 head hash for replay protection.

### L1 SLOAD (0x0102)

```solidity
address constant L1S = 0x0000000000000000000000000000000000000102;

function readCountL1SLOAD(address l1) external {
  (bool ok, bytes memory ret) = L1S.staticcall(
      abi.encode(l1, bytes32(uint256(0)))  // slot0
  );
  require(ok);
  emit ReadByL1SLOAD(abi.decode(ret, (uint))); 
}
```

This precompile reads storage slots directly from L1 using batched `eth_getStorageAt` calls.

## Usage Guide

| Use Case | Recommended Precompile | Return Value | Gas Cost (Conceptual) |
|----------|------------------------|--------------|------------------------|
| Call L1 contract view functions | 0x0101 Remote Static Call | Any ABI-encoded data | 21000 + 16 × calldataLen |
| Direct read L1 storage slots (max 5) | 0x0102 L1 SLOAD | 32B×N concatenated bytes | 2000 + 2000×N |

*Note: Slot count and gas costs may be adjusted in production networks.*

## Building

```shell
forge build
```
