# POST /swap-instruction

Returns an optimal swap quote and decomposed raw Solana instructions. The caller assembles them into a custom transaction for greater flexibility.

---

## Request

`POST /swap-instruction` with JSON body.

Request parameters are identical to [`POST /swap`](api-swap).

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
| `enableJit` | Boolean | No | Default is `false` (JIT post-processing **disabled**, opt-in). When `true`, enables JIT candidate-pool post-processing so `routerResult.dexRouterList[].candidates` is populated. See [`POST /swap` → JIT Candidate Pools](api-swap#jit-candidate-pools) |
| `enableCyclicArbitrage` | Boolean | No | Default is `false`. When enabled, enables cyclic arbitrage mode. `fromTokenAddress` and `toTokenAddress` must be the same, forming a circular route. See [Cyclic Arbitrage Mode](cyclic-arbitrage) |
| `cyclicArbitrageIntermediateTokens` | String | No | Custom intermediate token mints, comma-separated. Only effective when `enableCyclicArbitrage` is `true`. See [Cyclic Arbitrage Mode](cyclic-arbitrage) for how these are used and sizing guidance |
| `maxAccounts` | String | No | Provides an estimate of the maximum number of accounts that used for an instruction. It's useful when composing your own transaction, or if you want more precise resource accounting to optimize routing. Default: `64` |
| `swapReceiverAddress` | String | No | Recipient address of a purchased token. If not set, `userWalletAddress` will receive a purchased token |
| `computeUnitPrice` | String | No | Used for transactions on the Solana network and similar to gasPrice on Ethereum. This price determines the priority level of the transaction. The higher the price, the more likely that the transaction can be processed faster |
| `computeUnitLimit` | String | No | Used for transactions on the Solana network and analogous to gasLimit on Ethereum, which ensures that the transaction won't take too much computing resource. If the parameter `tips` is not `0`, then `computeUnitLimit` should be set to `0`. Otherwise, the fee is wasted |
| `tips` | String | No | Jito tips in lamports. This is used for MEV protection |
| `tipsReceiver` | String | No | Custom destination (base58 32-byte Solana address) for the tip transfer. When set and valid, the `tipInstruction` targets this address instead of a random Jito tip account, and the custom path has **no** `MIN_TIP_LAMPORTS` gate — the tip is emitted for any `tips > 0`. When omitted, Jito behavior is unchanged (random account, `tips > 1000` gate). No pairing constraint with `tips`. Empty / invalid base58 / non-32-byte → `INVALID_TIPS_RECEIVER` (validated before quoting). |
| `useTokenLedger` | Boolean | No | Default is `false`. When `true` (non-cyclic), `swapInstruction` derives its input amount on-chain from the token-ledger delta instead of a fixed amount: insert your own deposit instruction(s) between `tokenLedgerInstruction` and `swapInstruction`, and the deposited amount becomes the swap input. This standalone shape is supported **only** on this endpoint (`/swap` rejects it with `INVALID_TOKEN_LEDGER_MODE`, since a self-contained transaction has no deposit and its input amount would always be 0). With `enableCyclicArbitrage=true` it instead selects the cyclic instruction shape: `true` → two-leg A2A split, `false` → single whole-cycle instruction |
| `positiveSlippageReceiverAddress` | String | No | Recipient address that captures the positive-slippage portion when the on-chain `actual_amount_out` exceeds the quoted output. Must be paired with `positiveSlippageBps` (XOR — either both fields are set or both are omitted). See [`POST /swap` → Positive Slippage Capture](api-swap#positive-slippage-capture) |
| `positiveSlippageBps` | Number | No | Positive-slippage capture rate in basis points (1 bps = 0.01%). Range `[0, 1000]` (i.e. ≤ 10%), and must be a multiple of `10` when greater than `0`. Must be paired with `positiveSlippageReceiverAddress`. See [`POST /swap` → Positive Slippage Capture](api-swap#positive-slippage-capture) |
| `expectAmountOut` | String | No | Caller-supplied override for the swap instruction's expected output amount (the on-chain `min_out` basis). When set, the value is encoded into the `swapInstruction` bytes in place of the quote-derived output; slippage is still applied once on-chain. Must be `> 0` (passing `"0"` returns `INVALID_EXPECT_AMOUNT_OUT`); omitted/`null` leaves behavior unchanged. In cyclic-arbitrage mode it applies to the second leg (`otherInstructions[0]`) only. Note: this response has no `tx.minReceiveAmount` field, so the override is reflected only in the instruction bytes. |

> When trim is enabled (`bps > 0`), the change to `swapInstruction` is minimal and deterministic: the last byte of `swapInstruction.data` changes from `0x00` to `(bps / 10) as u8`, and `swapInstruction.accounts` gains one extra writable, non-signer entry at the tail (the receiver). All other bytes — including `setupInstructions`, `cleanupInstruction`, `otherInstructions`, and the rest of `swapInstruction.data` — are unchanged from the no-trim path. See [`POST /swap` → Positive Slippage Capture](api-swap#positive-slippage-capture) for the formula and the SA-proxy protocol restriction.


## Response

| Field | Type | Description |
|-------|------|-------------|
| `tokenLedgerInstruction` | Instruction | Token ledger snapshot instruction. Present when `useTokenLedger=true` **or** `enableCyclicArbitrage=true`. With `useTokenLedger=true` it snapshots the source ATA and pairs with `swapInstruction`; in cyclic mode it snapshots the intermediate-token ATA and pairs with `otherInstructions[0]` (leg-2) |
| `computeBudgetInstructions` | Instruction[] | Compute budget instructions: `[SetComputeUnitLimit, SetComputeUnitPrice]`. When the route spans **4 or more pools** (JIT candidate pools counted individually), a `RequestHeapFrame` is inserted between them — `[SetComputeUnitLimit, RequestHeapFrame, SetComputeUnitPrice]` — to grow the on-chain heap (64KB–256KB, scaling with pool count) and avoid heap overflow |
| `setupInstructions` | Instruction[] | Token-account housekeeping ran **before** the swap (ATA creation + native-SOL wrap). Always non-empty. See [Setup & Cleanup Instructions](#setup--cleanup-instructions) |
| `swapInstruction` | Instruction | Core swap instruction |
| `cleanupInstruction` | Instruction | Token-account housekeeping ran **after** the swap. `null` unless the user is receiving native SOL — in that case it unwraps the wSOL ATA back to native SOL. See [Setup & Cleanup Instructions](#setup--cleanup-instructions) |
| `otherInstructions` | Instruction[] | Additional instructions (e.g. cyclic arbitrage second leg) |
| `tipInstruction` | Instruction | Jito tip transfer instruction (present when `tips` is set). Destination is a random Jito tip account by default, or `tipsReceiver` when that field is supplied. The response schema is unchanged — the custom receiver only changes the transfer's destination account. |
| `addressLookupTableAddresses` | String[] | Address Lookup Table Account. Used to optimize the management and referencing of addresses in transactions by storing related addresses in a table and referencing them via index values |
| `prioritizationFeeLamports` | String | Total prioritization fee in lamports |
| `blockhashWithMetadata` | BlockhashMetadata | Recent blockhash and its last valid block height |
| `routerResult` | QuoteResponse | Quote path data (see [`POST /swap`](api-swap)) |

### Instruction

| Field | Type | Description |
|-------|------|-------------|
| `programId` | String | Program ID for instruction execution |
| `accounts` | AccountMeta[] | Instruction account information |
| `data` | String | Instruction data (base64 encoded) |

### AccountMeta

| Field | Type | Description |
|-------|------|-------------|
| `pubkey` | String | Public key address of the account |
| `isSigner` | Boolean | Whether the account is a signer |
| `isWritable` | Boolean | Whether the account is writable |

### BlockhashMetadata

| Field | Type | Description |
|-------|------|-------------|
| `blockhash` | String | Recent blockhash (base58) |
| `lastValidBlockHeight` | String | Last valid block height for this blockhash |

---

## Setup & Cleanup Instructions

The `setupInstructions` and `cleanupInstruction` fields handle Solana-specific token-account housekeeping (ATA creation and native-SOL wrap / unwrap). The server fully populates them — callers do **not** need to add their own ATA-creation or wrap logic. Just append them to the transaction in the order shown under [Transaction Assembly Order](#transaction-assembly-order).

> **Native SOL vs wSOL — important.** Throughout this section, "native SOL" means the system-program address `11111111111111111111111111111111`. The wSOL **mint** literal `So11111111111111111111111111111111111111112` is treated as a regular SPL token and does **not** trigger wrap or unwrap.

### setupInstructions

`setupInstructions` is **always non-empty**. Its contents appear in this fixed order:

| # | Segment | Count | When it appears |
|---|---|---|---|
| 1 | `createDestinationATA` | always 1 | **Always.** Uses the SPL `CreateIdempotent` variant, so it is a chain-side no-op when the user already owns the destination ATA. For Token-2022 destination mints, this instruction automatically targets the Token-2022 program. |
| 2 | `createUserIntermediateATA` | 0 or 1 | Only when `enableCyclicArbitrage = true`. Pre-creates the user's intermediate-token ATA so the cyclic-arbitrage `set_token_ledger` step has a valid target. |
| 3 | `createIntermediateSaATA[…]` | 0 or more | Only when the route has ≥ 2 hops **and** an intermediate mint is not in the server's base-token whitelist (SOL / USDC / USDT / …). These create the router service-account (SA) ATAs that hold balances between hops. |
| 4 | wSOL **wrap triplet**: `wrapSolCreateATA` + `systemTransfer` + `syncNative` | always 3 (as a unit) | Only when `fromTokenAddress` is native SOL (`11111…1`). The three instructions are always emitted together. |

### cleanupInstruction

Governed by **one rule**:

| `toTokenAddress` | `cleanupInstruction` |
|---|---|
| native SOL (`11111…1`) | SPL Token `CloseAccount` on the user's destination wSOL ATA → underlying lamports (rent + token balance) return to the wallet as native SOL |
| any SPL mint (including the wSOL literal `So11…2`) | `null` |

It does **not** depend on `useTokenLedger`, `enableCyclicArbitrage`, route length, or whether the destination ATA was newly created.

### Examples

Six common scenarios. `U` denotes the user wallet; "wSOL ATA" denotes `U`'s associated token account for the wSOL mint.

#### 1. SPL → SPL, single hop (USDC → USDT)

```
setupInstructions = [ createDestATA(USDT) ]          // length 1
cleanupInstruction = null
```

#### 2. SPL → native SOL (USDC → SOL)

```
setupInstructions = [ createDestATA(wSOL) ]          // length 1
cleanupInstruction = closeAccount(U's wSOL ATA)      // unwrap to native SOL
```

No wrap triplet — the source is an SPL token, not native SOL.

#### 3. native SOL → SPL (SOL → USDC)

```
setupInstructions = [
  createDestATA(USDC),
  wrapCreateATA(wSOL),                               // ┐
  systemTransfer(amount lamports → U's wSOL ATA),    // │ wrap triplet
  syncNative(U's wSOL ATA),                          // ┘
]                                                     // length 4
cleanupInstruction = null
```

#### 4. SPL → SPL, three hops (USDC → X → Y → BONK, X and Y both off the whitelist)

```
setupInstructions = [
  createDestATA(BONK),
  createIntermediateSaATA(X),
  createIntermediateSaATA(Y),
]                                                     // length 3
cleanupInstruction = null
```

If `X` were USDC (on the base-token whitelist), the matching entry would be skipped and the length would drop to 2.

#### 5. Cyclic arbitrage, SPL ⇆ SPL (A → B → A)

```
setupInstructions = [
  createDestATA(A),                                  // dest = source = A, still emitted (idempotent)
  createUserIntermediateATA(B),                      // for set_token_ledger
  createIntermediateSaATA(B),                        // if B is off the whitelist
]                                                     // length 3 (or 2 if B is whitelisted)
cleanupInstruction = null
```

Note: the cyclic route is split between two ix — `swapInstruction` carries leg-1 (A → B), `otherInstructions[0]` carries leg-2 (B → A). See [Cyclic-arbitrage slippage](#cyclic-arbitrage-slippage).

#### 6. Cyclic arbitrage, native SOL ⇆ native SOL (SOL → B → SOL)

```
setupInstructions = [
  createDestATA(wSOL),                               // ┐ both point at U's wSOL ATA;
  createUserIntermediateATA(B),                      // │ duplication is intentional —
  createIntermediateSaATA(B),                        // │ do NOT deduplicate client-side.
  wrapCreateATA(wSOL),                               // ┘
  systemTransfer(amount lamports → U's wSOL ATA),
  syncNative(U's wSOL ATA),
]                                                     // length 6
cleanupInstruction = closeAccount(U's wSOL ATA)      // unwrap to native SOL
```

The duplicate wSOL ATA reference (`createDestATA` + `wrapCreateATA`) is by design — `CreateIdempotent` is a chain-side no-op when the account already exists, and keeping the rule uniform makes the four builder paths behave identically.

### Cyclic-arbitrage slippage

When `enableCyclicArbitrage = true`, the route is split into two router instructions:

- **leg-1** lives in `swapInstruction`. Its on-chain `min_out` is hard-coded to `1` (the user-supplied slippage does not apply to the intermediate token, and on-chain rejects `min_out = 0`).
- **leg-2…N** lives in `otherInstructions[0]`. Its on-chain `min_out` equals the quoted final output of the loop token (or `expectAmountOut`, when supplied), with the user-supplied `slippagePercent` rounded to bps. This is the lower bound the user actually cares about.

`tx.minReceiveAmount` (in `routerResult`) reflects the leg-2 bound.

### Empty route

If routing finds no path (e.g. pool data not yet loaded), the endpoint returns HTTP 200 with business error code `NO_ROUTE_FOUND` (see [API errors](api-errors)). Treat it as a transient retry condition.

---

## Transaction Assembly Order

Assemble instructions into a Solana transaction in this order (identical to what `POST /swap` builds internally):

1. `computeBudgetInstructions`
2. `setupInstructions`
3. `tokenLedgerInstruction` (if present)
4. `swapInstruction`
5. `otherInstructions`
6. `cleanupInstruction` (if present)
7. `tipInstruction` (if present)

Two ordering rules are load-bearing:

- `tokenLedgerInstruction` must run **after** `setupInstructions`: the ATA it snapshots (intermediate-token ATA in cyclic mode; source wSOL ATA for native-SOL input) may only be created by `setupInstructions`, and the snapshot fails on a non-existent account.
- `cleanupInstruction` must run **after** `otherInstructions`: in SOL ⇆ SOL cyclic arbitrage, cleanup closes the user's wSOL ATA that leg-2 (`otherInstructions[0]`) still deposits into.

With `useTokenLedger=true` (non-cyclic), insert your own deposit instruction(s) between 3 and 4 — the on-chain input amount is the balance delta since the snapshot.

Use `addressLookupTableAddresses` to fetch ALTs for building a Versioned Transaction, then sign and submit.

---

## Example

```bash
curl -s -X POST 'http://localhost:8080/swap-instruction' \
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
  "computeBudgetInstructions": [
    {
      "programId": "ComputeBudget111111111111111111111111111111",
      "accounts": [],
      "data": "AgY6BAA="
    },
    {
      "programId": "ComputeBudget111111111111111111111111111111",
      "accounts": [],
      "data": "Axm5AgAAAAAA"
    }
  ],
  "setupInstructions": [
    {
      "programId": "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL",
      "accounts": [
        {"pubkey": "...", "isSigner": true, "isWritable": true},
        {"pubkey": "...", "isSigner": false, "isWritable": true}
      ],
      "data": ""
    }
  ],
  "swapInstruction": {
    "programId": "proVF4pMXVaYqmy4NjniPh4pqKNfMmsihgd4wdkCX3u",
    "accounts": [
      {"pubkey": "...", "isSigner": true, "isWritable": true}
    ],
    "data": "..."
  },
  "cleanupInstruction": null,
  "otherInstructions": [],
  "tipInstruction": null,
  "addressLookupTableAddresses": [
    "...",
    "..."
  ],
  "prioritizationFeeLamports": "200000",
  "blockhashWithMetadata": {
    "blockhash": "GHtXQBpY7s...",
    "lastValidBlockHeight": "123456789"
  },
  "routerResult": {
    "fromTokenAddress": "So11111111111111111111111111111111111111112",
    "toTokenAddress": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
    "fromTokenAmount": "1000000000",
    "toTokenAmount": "87521745",
    "contextSlot": "310482917",
    "slippagePercent": "0.5",
    "dexRouterList": [...]
  }
}
```
