# hash256-cli

CPU CLI miner for [hash256.org](https://hash256.org/mine). It reuses the official browser WASM miner and submits successful nonces directly to the HASH Ethereum mainnet contract.

Contract: `0xAC7b5d06fa1e77D08aea40d46cB7C5923A87A0cc`

## Install

```bash
cd ~/projects/hash256-cli
npm install
```

## Configure private key

Use a fresh mining wallet with limited ETH for gas.

```bash
export HASH256_PRIVATE_KEY=0xyour_private_key_here
```

Optional RPC override:

```bash
export HASH256_RPC_URL=https://ethereum.publicnode.com
```

## Run

Default RPC is Ethereum mainnet public RPC. Default threads = all CPU threads reported by Node.

```bash
npm run mine
```

Equivalent direct command:

```bash
node src/cli.js
```

Useful options:

```bash
node src/cli.js --status                     # chain status only; no key needed
node src/cli.js --benchmark --address 0x...   # mine locally without submitting
node src/cli.js --threads 8                   # override thread count
node src/cli.js --rpc https://...             # override RPC
node src/cli.js --priority-fee-gwei 3         # faster inclusion; default 2 gwei
node src/cli.js --max-fee-gwei 10             # optional fee cap override
node src/cli.js --once                        # stop after one successful mined tx
node src/cli.js --no-submit                   # find nonce but do not send tx
```

## Notes

- This is CPU mining, not GPU.
- Mining challenge is bound to the wallet address.
- The CLI queries `getChallenge(address)` and `miningState()`, searches nonce locally, then calls `mine(uint256 nonce)`.
- Public RPCs can rate limit. For real mining, a private/mainstream RPC endpoint is recommended.
- Submitting a found nonce costs Ethereum mainnet gas; failed/stale submissions may still cost gas if broadcast.
- If mined nonces often revert after being sent, raise inclusion speed with `--priority-fee-gwei 3` or `--max-fee-gwei 10`. Reverts are usually stale epoch/difficulty, not gas-limit exhaustion.

## Credits

Based on [haha256](https://github.com/vcing/haha256) by [@vcing](https://github.com/vcing).
GPU mining extension (standalone C OpenCL miner, no SDK headers required) added in this fork.
