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
| `enableCyclicArbitrage` | Boolean | No | Default is `false`. When enabled, enables cyclic arbitrage mode. `fromTokenAddress` and `toTokenAddress` must be the same, forming a circular route |
| `cyclicArbitrageIntermediateTokens` | String | No | Custom intermediate token mints, comma-separated. Only effective when `enableCyclicArbitrage` is `true` |
| `maxAccounts` | String | No | Provides an estimate of the maximum number of accounts that used for an instruction. It's useful when composing your own transaction, or if you want more precise resource accounting to optimize routing. Default: `64` |
| `swapReceiverAddress` | String | No | Recipient address of a purchased token. If not set, `userWalletAddress` will receive a purchased token |
| `computeUnitPrice` | String | No | Used for transactions on the Solana network and similar to gasPrice on Ethereum. This price determines the priority level of the transaction. The higher the price, the more likely that the transaction can be processed faster |
| `computeUnitLimit` | String | No | Used for transactions on the Solana network and analogous to gasLimit on Ethereum, which ensures that the transaction won't take too much computing resource. If the parameter `tips` is not `0`, then `computeUnitLimit` should be set to `0`. Otherwise, the fee is wasted |
| `tips` | String | No | Jito tips in lamports. This is used for MEV protection |
| `useTokenLedger` | Boolean | No | Default is `false`. When `true`, uses token ledger for dynamic input amount detection |

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

### TxMeta

| Field | Type | Description |
|-------|------|-------------|
| `from` | String | User's wallet address |
| `to` | String | The contract address of OKX DEX router |
| `minReceiveAmount` | String | The minimum amount of a token to buy when the price reaches the upper limit of slippage (e.g., `87084137`) |
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
        "percent": "60"
      },
      {
        "fromTokenAddress": "So11111111111111111111111111111111111111112",
        "toTokenAddress": "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
        "fromTokenIndex": "0",
        "toTokenIndex": "2",
        "poolAddress": "4GkRbcYg1VKsZropgai4dMf2418GNJRF1QwNe54CsBD5",
        "percent": "40"
      },
      {
        "fromTokenAddress": "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
        "toTokenAddress": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        "fromTokenIndex": "2",
        "toTokenIndex": "1",
        "poolAddress": "EqnbDgR8e7K6h1xoLKaLLSBt4vDPiXApkDmTmFnRe14",
        "percent": "100"
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