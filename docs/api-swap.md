# POST /swap

Returns an optimal swap quote and a base64-encoded unsigned Solana transaction. The caller signs and submits it on-chain.

---

## Request

`POST /swap` with JSON body.

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `pallas-debug` | No | Debug switch (presence-only, case-insensitive). When this header is present on the request — with any value, including an empty one — the server logs the full JSON-serialized response at `info` level. Omit the header for normal traffic; requests without it incur zero overhead |

### Parameters

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fromTokenAddress` | String | Yes | The contract address of a token you want to send (e.g., `So11111111111111111111111111111111111111112`) |
| `toTokenAddress` | String | Yes | The contract address of a token you want to receive (e.g., `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v`) |
| `amount` | String | Yes | The input amount of a token to be sold (set in minimal divisible units, e.g., 1.00 SOL set as `1000000000`) |
| `slippagePercent` | String | No | Slippage limit. The slippage setting has a minimum value of `0` and a maximum value of less than `100` (e.g., `0.5` means that the maximum slippage for this transaction is `0.5%`). Default: `0.5` |
| `userWalletAddress` | String | Yes | User's wallet address (e.g., `J5CBzXpcYn6WR2JBah8zU4Yxct985CAFGwXRcFaX2pbS`) |
| `dexIds` | String | No | DexId of the liquidity pool for limited quotes, multiple combinations separated by `,`. Use `/program-id-to-label` to look up IDs |
| `excludedDexIds` | String | No | The dexId of the liquidity pool that will not be used, multiple combinations separated by `,` |
| `directRoute` | Boolean | No | Default is `false`. When enabled, restricts routing to a single liquidity pool only |
| `singleRouteOnly` | Boolean | No | Default is `false`. When enabled, routing is restricted to a single route. Multi-hop and multi-pool routes are allowed, but no parallel split routes will be constructed |
| `singlePoolPerHop` | Boolean | No | Default is `false`. When enabled, each hop in the route is restricted to a single pool |
| `stableIntermediateTokensOnly` | Boolean | No | Default is `false`. When enabled, routing will restrict intermediate tokens to stablecoins (e.g. USDC, USDT) to reduce high-slippage path risk |
| `enableJit` | Boolean | No | Default is `false` (JIT post-processing **disabled**, opt-in). When `true`, enables JIT candidate-pool post-processing so `dexRouterList[].candidates` is populated and the candidate pools are translated into the built transaction. See [JIT Candidate Pools](#jit-candidate-pools) |
| `enableCyclicArbitrage` | Boolean | No | Default is `false`. When enabled, enables cyclic arbitrage mode. `fromTokenAddress` and `toTokenAddress` must be the same, forming a circular route. See [Cyclic Arbitrage Mode](cyclic-arbitrage) |
| `cyclicArbitrageIntermediateTokens` | String | No | Custom intermediate token mints, comma-separated. Only effective when `enableCyclicArbitrage` is `true`. See [Cyclic Arbitrage Mode](cyclic-arbitrage) for how these are used and sizing guidance |
| `maxAccounts` | String | No | Provides an estimate of the maximum number of accounts that used for an instruction. It's useful when composing your own transaction, or if you want more precise resource accounting to optimize routing. Default: `64` |
| `swapReceiverAddress` | String | No | Recipient address of a purchased token. If not set, `userWalletAddress` will receive a purchased token |
| `computeUnitPrice` | String | No | Used for transactions on the Solana network and similar to gasPrice on Ethereum. This price determines the priority level of the transaction. The higher the price, the more likely that the transaction can be processed faster |
| `computeUnitLimit` | String | No | Used for transactions on the Solana network and analogous to gasLimit on Ethereum, which ensures that the transaction won't take too much computing resource. If the parameter `tips` is not `0`, then `computeUnitLimit` should be set to `0`. Otherwise, the fee is wasted |
| `tips` | String | No | Jito tips in lamports. This is used for MEV protection |
| `tipsReceiver` | String | No | Custom destination (base58 32-byte Solana address) for the tip transfer. When set and valid, the single tip `SystemProgram::transfer` targets this address instead of a random Jito tip account, and the custom path has **no** `MIN_TIP_LAMPORTS` gate — the tip is emitted for any `tips > 0`. When omitted, all existing Jito behavior is unchanged (random account, `tips > 1000` gate). No pairing constraint with `tips` (a `tipsReceiver` without `tips` is accepted and simply has no effect). Empty / invalid base58 / non-32-byte → `INVALID_TIPS_RECEIVER` (validated before quoting; no fallback to a Jito account). |
| `useTokenLedger` | Boolean | No | Default is `false`. Selects the cyclic-arbitrage instruction shape: with `enableCyclicArbitrage=true`, `true` builds the two-leg A2A split (`setTokenLedger` + leg-1 + ledger leg-2) while `false` (default) builds a single whole-cycle swap instruction. On `/swap`, `useTokenLedger=true` **requires** `enableCyclicArbitrage=true` — the standalone token-ledger shape is rejected with `INVALID_TOKEN_LEDGER_MODE`, because a self-contained transaction has nothing funding the source token account after the ledger snapshot, so its on-chain input amount is always 0 and it can never execute. For the standalone shape, use [`POST /swap-instruction`](api-swap-instruction) and insert your own deposit instruction(s) after the snapshot |
| `positiveSlippageReceiverAddress` | String | No | Recipient address that captures the positive-slippage portion when the on-chain `actual_amount_out` exceeds the quoted output. Must be paired with `positiveSlippageBps` (XOR — either both fields are set or both are omitted). See [Positive Slippage Capture](#positive-slippage-capture) |
| `positiveSlippageBps` | Number | No | Positive-slippage capture rate in basis points (1 bps = 0.01%). Range `[0, 1000]` (i.e. ≤ 10%), and must be a multiple of `10` when greater than `0`. Must be paired with `positiveSlippageReceiverAddress`. See [Positive Slippage Capture](#positive-slippage-capture) |
| `expectAmountOut` | String | No | Caller-supplied override for the swap instruction's expected output amount, replacing the value Pallas would otherwise derive from the quote. When set, it becomes the basis for the on-chain `min_out` (`min_out = expectAmountOut × (10000 − slippageBps) / 10000`) and for the response `tx.minReceiveAmount`; slippage is still applied once and `routerResult` still reflects the engine's quote. Must be `> 0` (passing `"0"` returns `INVALID_EXPECT_AMOUNT_OUT`). Omitted/`null` → behavior is unchanged (quote output is used). In cyclic-arbitrage mode it applies to the second leg only. |

---

## Positive Slippage Capture

When `positiveSlippageReceiverAddress` and `positiveSlippageBps` are both supplied and `bps > 0`, the OKX router contract diverts a bounded share of any positive slippage (i.e. when the actual on-chain output exceeds the quoted output) to the receiver address; the remainder still goes to the user.

**Formula** (contract `swap_with_fees.rs` / `fee.rs`):

```
trim_rate    = (positiveSlippageBps / 10) as u8        // ∈ [0, 100]
trim_amount  = min(
    actual_amount_out - expect_amount_out,             // surplus over quote
    actual_amount_out × trim_rate / 1_000              // 0.1% precision cap
)
```

The trim only fires when the actual output exceeds the quote; if the swap lands at or below the quoted output, nothing is diverted and the receiver gets `0`.

**Behavior notes**:

- Omitting both fields (or supplying `bps = 0`) disables the feature — instruction bytes are bit-for-bit identical to the no-trim path.
- **Cyclic arbitrage** (`enableCyclicArbitrage = true`): the first leg never applies trim (intermediate-token surplus has no user-protection meaning). The final leg of the cycle applies the user-supplied parameters.
- **`maxAccounts`**: when trim is enabled, the swap instruction's account list contains one extra slot (the receiver). A request with `maxAccounts = 64` may therefore produce a transaction with 65 accounts. This is well below Solana's 256-account versioned-transaction ceiling.
- **Protocol restriction (hard contract constraint)**: trim is only valid on SA-proxy protocols (e.g. BisonFi / AlphaQ / ZeroFi / TaurusFi). Enabling trim on a non-SA-proxy protocol (Raydium / Orca / Meteora / …) causes the on-chain instruction to fail with `SaAuthorityIsNone (6056)`. The API does not pre-reject such combinations because the final routed protocol set is not known until quote time — callers must restrict routing via `dexIds` when enabling trim.

See [API errors](api-errors) for the four `INVALID_POSITIVE_SLIPPAGE_*` validation codes.

---

## JIT Candidate Pools

JIT post-processing is **off by default** and is enabled per request via `enableJit: true`. When enabled, Pallas attaches **alternative liquidity pools** to the quoted route as a purely additive hint. The quote and the selected route are never changed — this only fills the `dexRouterList[].candidates` field, so a downstream submitter can optionally substitute a Just-In-Time (JIT) liquidity pool for the chosen pool at execution time.

**How it works** (runs after the route is assembled):

1. The set of JIT-eligible DEX protocols is pushed by the OKX Hub and refreshed periodically (market-maker protocols such as Manifest, HumiDiFi, Tessera, GoonfiV2). If the Hub-pushed set is empty, JIT post-processing is disabled.
2. Among the route hops whose pool belongs to a JIT-eligible protocol, the single hop carrying the largest share of total input flow is selected (ties resolved to the earliest hop). Flow share is the topological share of input routed through the hop — not the hop-local `percent`.
3. That hop's token pair is re-quoted, excluding the already-selected pool and restricted to JIT-eligible protocols; the best-output alternative pool address is appended to that hop's `candidates`.

**Guarantees**

- Purely additive — `toTokenAmount`, the `dexRouterList` pools, and the `percent` values are never altered. Only `candidates` is populated.
- At most one hop receives candidates per quote.
- `candidates` is always present in the response. It is an empty array (`[]`) when JIT is not enabled (the default), no hop uses a JIT-eligible protocol, or no alternative pool quotes.

**Enabling** — JIT post-processing is off by default; set the request parameter `enableJit: true` to turn it on. Without it every `candidates` stays `[]`.

This feature also applies in [cyclic-arbitrage mode](cyclic-arbitrage).

---

## Response

| Field | Type | Description |
|-------|------|-------------|
| `swapTransactionData` | String | Base64-encoded unsigned transaction |
| `lastValidBlockHeight` | String | Last valid block height for the transaction |
| `contextSlot` | String | Latest Solana slot at response time |
| `routerResult` | QuoteResponse | Quote path data |
| `tx` | TxMeta | Transaction metadata |

### QuoteResponse

| Field | Type | Description |
|-------|------|-------------|
| `fromTokenAddress` | String | Token contract address of the token to be sold |
| `toTokenAddress` | String | Token contract address of the token to be bought |
| `fromTokenAmount` | String | The input amount of a token to be sold (e.g., `1000000000`) |
| `toTokenAmount` | String | The resulting amount of a token to be bought (e.g., `87521745`) |
| `contextSlot` | String | Solana slot at quote time |
| `slippagePercent` | String | The value of current transaction slippage |
| `dexRouterList` | DexRouter[] | Quote path data set |

### DexRouter

| Field | Type | Description |
|-------|------|-------------|
| `fromTokenAddress` | String | Token contract address of the token being sold in this step |
| `toTokenAddress` | String | Token contract address of the token being bought in this step |
| `fromTokenIndex` | String | Token index of fromToken in the swap path |
| `toTokenIndex` | String | Token index of toToken in the swap path |
| `poolAddress` | String | On-chain address of the liquidity pool used in this step (base58) |
| `percent` | String | The percentage of assets handled by the protocol (e.g., `60`) |
| `candidates` | String[] | Alternative JIT-eligible pool addresses (base58) that may be substituted for `poolAddress` in this step. Always present; empty (`[]`) unless JIT post-processing attached a candidate to this hop. See [JIT Candidate Pools](#jit-candidate-pools) |

### TxMeta

| Field | Type | Description |
|-------|------|-------------|
| `from` | String | User's wallet address |
| `to` | String | The contract address of OKX DEX router |
| `minReceiveAmount` | String | The minimum amount of a token to buy when the price reaches the upper limit of slippage (e.g., `87084137`). Derived from the quote output by default; when `expectAmountOut` is supplied, it is derived from that override instead (same slippage formula). |
| `slippagePercent` | String | The value of current transaction slippage |

---

## Example

```bash
curl -s -X POST 'http://localhost:8080/swap' \
  -H 'Content-Type: application/json' \
  -d '{
    "fromTokenAddress": "So11111111111111111111111111111111111111112",
    "toTokenAddress": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
    "amount": "1000000000",
    "slippagePercent": "0.5",
    "userWalletAddress": "YOUR_WALLET_PUBLIC_KEY"
  }'
```

```json
{
  "swapTransactionData": "AQAAAA...base64...",
  "lastValidBlockHeight": "123456789",
  "contextSlot": "310482917",
  "routerResult": {
    "fromTokenAddress": "So11111111111111111111111111111111111111112",
    "toTokenAddress": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
    "fromTokenAmount": "1000000000",
    "toTokenAmount": "87521745",
    "contextSlot": "310482917",
    "slippagePercent": "0.5",
    "dexRouterList": [
      {
        "fromTokenAddress": "So11111111111111111111111111111111111111112",
        "toTokenAddress": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        "fromTokenIndex": "0",
        "toTokenIndex": "1",
        "poolAddress": "8sLbNZoA1cfnvMJLPfp98ZLAnFSYCFApfJKMbiXNLwxj",
        "percent": "60",
        "candidates": ["ENhU8LsaR7vDD2G1CsWcsuSGNrih9Cv5WZEk7q9kPapQ"]
      },
      {
        "fromTokenAddress": "So11111111111111111111111111111111111111112",
        "toTokenAddress": "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
        "fromTokenIndex": "0",
        "toTokenIndex": "2",
        "poolAddress": "4GkRbcYg1VKsZropgai4dMf2418GNJRF1QwNe54CsBD5",
        "percent": "40",
        "candidates": []
      },
      {
        "fromTokenAddress": "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
        "toTokenAddress": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        "fromTokenIndex": "2",
        "toTokenIndex": "1",
        "poolAddress": "EqnbDgR8e7K6h1xoLKaLLSBt4vDPiXApkDmTmFnRe14",
        "percent": "100",
        "candidates": []
      }
    ]
  },
  "tx": {
    "from": "YOUR_WALLET_PUBLIC_KEY",
    "to": "proVF4pMXVaYqmy4NjniPh4pqKNfMmsihgd4wdkCX3u",
    "minReceiveAmount": "87084137",
    "slippagePercent": "0.5"
  }
}
```