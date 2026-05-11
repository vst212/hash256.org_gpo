# hash256-cli

CPU / GPU CLI miner for [hash256.org](https://hash256.org/mine).  
Reuses the official browser WASM miner and submits successful nonces directly to the HASH Ethereum mainnet contract.

Contract: [`0xAC7b5d06fa1e77D08aea40d46cB7C5923A87A0cc`](https://etherscan.io/address/0xAC7b5d06fa1e77D08aea40d46cB7C5923A87A0cc)

---

## Understanding the Game — Why "Mining is not open"?

### Three-Phase Launch

HASH follows a strict three-phase lifecycle enforced entirely on-chain:

```
Phase 1 · GENESIS  →  Phase 2 · SEED  →  Phase 3 · MINING (open)
```

**Phase 1 · Genesis Mint** *(currently active / may be incomplete)*  
- 1,050,000 HASH sold at a fixed price of **0.01 ETH per 1,000 HASH** (~$0.03/HASH)  
- Max 5,000 HASH per transaction · no per-wallet cap · first come first served  
- All raised ETH is locked inside the contract until the pool is seeded  
- Closes automatically when 1,050,000 HASH is fully sold  
- ➜ https://hash256.org/ (Genesis page)

**Phase 2 · Seed Pool**  
- After Genesis sells out, anyone can call `seedPool()` on the contract  
- The contract atomically mints another 1,050,000 HASH and seeds a **Uniswap V4 ETH/HASH pool** with 10.5 ETH + 1,050,000 HASH  
- The LP position is locked forever — no one can remove it  
- Pool opens at the same $0.03 launch price

**Phase 3 · Mining Opens**  
- Only after `seedPool()` is called does `genesisComplete` flip to `true`  
- The contract then accepts `mine(nonce)` calls  
- This CLI becomes usable at this point

---

### How the PoW Puzzle Works

```
challenge  = keccak256(chainId ‖ contract ‖ miner_address ‖ epoch)
valid nonce = keccak256(challenge ‖ nonce) < currentDifficulty
```

| Property | Detail |
|---|---|
| Address-bound | Your challenge is unique to your wallet — mempool sniping is impossible |
| Epoch rotation | Every ~100 blocks (~20 min) the challenge rotates — pre-computed solutions expire |
| Replay-proof | Each (miner, nonce, epoch) tuple can only mint once |
| Rate limit | Hard cap of 10 mints per block on-chain |

---

### Tokenomics & Halvings

Total supply: **21,000,000 HASH** (Bitcoin-style hard cap)

| Allocation | Amount |
|---|---|
| Genesis Mint | 1,050,000 HASH (5%) |
| LP Side (locked) | 1,050,000 HASH (5%) |
| Mining Rewards | 18,900,000 HASH (90%) |
| Team / VC / Airdrop | **0%** |

| Era | Reward / mint | Trigger |
|---|---|---|
| Era 1 | 100 HASH | starts at genesis complete |
| Era 2 | 50 HASH | after 100,000 mints |
| Era 3 | 25 HASH | after 200,000 mints |
| Era 4 | 12.5 HASH | after 300,000 mints |
| Era 5+ | 6.25 HASH | and so on… |

Difficulty retargets every **2,016 mints** (same formula as Bitcoin), targeting 1 mint/minute globally.  
Full distribution takes approximately **~290 days**.

---

## 游戏说明（简体中文）

### 为什么显示"Mining is not open"？

HASH 采用**三阶段上线机制**，均由智能合约强制执行：

**第一阶段 · Genesis 创世发行**（可能仍在进行中）
- 以固定价格 **0.01 ETH / 1,000 HASH**（约 $0.03/枚）发售 1,050,000 HASH
- 每笔交易最多购买 5,000 HASH，无钱包上限，先到先得
- 所有 ETH 锁定在合约内，直到流动池启动
- 售完后自动关闭
- ➜ 参与创世发行：https://hash256.org/

**第二阶段 · 启动流动池**
- 创世售完后，任何人都可以调用合约的 `seedPool()` 函数
- 合约自动将 10.5 ETH + 1,050,000 HASH 注入 Uniswap V4 流动池
- LP 永久锁定，无人可提取
- 初始价格与创世价格相同：$0.03

**第三阶段 · 挖矿开放**
- `seedPool()` 调用后，合约的 `genesisComplete` 变为 `true`
- 此时本 CLI 工具才可正常挖矿
- 提交有效 nonce 即可铸造 HASH 并直接发送到你的钱包

### 核心机制

- **工作量证明**：在本地暴力搜索 keccak256 哈希，找到小于当前难度目标的 nonce
- **地址绑定**：挑战值与你的钱包地址绑定，无法被抢跑
- **纪元轮换**：每约 20 分钟（100 个区块）更换挑战值，防止预计算
- **难度调整**：每 2,016 次铸造重新调整一次，目标全网 1 分钟一次铸造
- **减半机制**：每 100,000 次铸造奖励减半，总量硬上限 2,100 万枚

### 代币分配

| 类别 | 数量 |
|---|---|
| 创世发行 | 1,050,000 HASH（5%）|
| 流动池（永久锁定）| 1,050,000 HASH（5%）|
| 挖矿奖励 | 18,900,000 HASH（90%）|
| 团队 / 投资机构 / 空投 | **0%** |

### 重要链接

| 页面 | 链接 |
|---|---|
| 官网 & 创世发行 | https://hash256.org/ |
| 挖矿页面 | https://hash256.org/mine |
| 流动池 | https://hash256.org/pool |
| 交易动态 | https://hash256.org/feed |
| 白皮书 | https://hash256.org/whitepaper |
| 合约（Etherscan）| https://etherscan.io/address/0xAC7b5d06fa1e77D08aea40d46cB7C5923A87A0cc |
| 官方 X（Twitter）| https://x.com/hash256dotorg |

---

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
