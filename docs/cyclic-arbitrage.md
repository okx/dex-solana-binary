# Cyclic Arbitrage Mode

Cyclic arbitrage mode finds a profitable **round-trip** route — you send a token and receive the *same* token back, ending with more than you started with. It is enabled per request and is one of Pallas's headline routing capabilities.

It is controlled by these `/swap` and `/swap-instruction` parameters:

| Field | Description |
|-------|-------------|
| `enableCyclicArbitrage` | Set to `true` to enable the mode. `fromTokenAddress` and `toTokenAddress` must be the **same** mint, forming a circular route. |
| `cyclicArbitrageIntermediateTokens` | Comma-separated mints to consider as the loop's intermediate stops. Only effective when `enableCyclicArbitrage` is `true`. |
| `uniqueDexIds` | Optional comma-separated DEX program IDs. Each listed protocol may be used by at most one hop in the entire loop. A non-empty request value replaces the Hub-pushed default list. |
| `enableUniqueDex` | Enables the per-protocol uniqueness constraint. Default is `true`; set it to `false` to ignore both the request list and the Hub list. |
| `executionMode` | Selects the **instruction shape** of the built transaction (does not affect routing). One of `singleTx` (default) / `tokenLedger` / `maxIn`. Defaults to `singleTx`. See [Instruction shape](#instruction-shape) below. |

### Instruction shape

`executionMode` chooses how the cycle is encoded into instructions when `enableCyclicArbitrage` is `true`:

| `executionMode` | Shape | Instructions |
|------------|-------|--------------|
| `singleTx` (default) | **Single whole-cycle instruction** | one `swap_tob_v3` encoding the entire loop `A → … → A`; no `set_token_ledger`. Relies on the on-chain return-to-start normalization. |
| `tokenLedger` | **Three-instruction split (A2A, literal ledger)** | `set_token_ledger` (snapshots the intermediate token's ATA — MUST precede leg-1, since the contract derives leg-2's `amount_in` as `current_balance − snapshot`) + leg-1 `swap_tob_v3` (explicit `amount_in`, deposits into the intermediate ATA) + leg-2 `swap_tob_with_token_ledger_v3` (`amount_in` derived on-chain from the ledger balance delta). |
| `maxIn` | **Two-instruction split (A2A, Swap-Max)** | leg-1 `swap_tob_v3` + leg-2 `swap_tob_v3` (contract v3, Swap-Max). The first hop runs with an explicit `amount_in`; the remaining hops encode `amount_in` as a sentinel upper bound, resolved on-chain to `min(amount_in, balance) == balance` — no `set_token_ledger` snapshot instruction. |

Neither `executionMode=tokenLedger` nor `executionMode=maxIn` **requires** `enableCyclicArbitrage=true` — both also have a standalone (non-cyclic) shape, and in both cases that standalone shape is supported **only** on `/swap-instruction` (rejected on `/swap`, since a self-contained transaction has nothing funding the source/intermediate token account before the swap executes, so it could never succeed):

- `executionMode=tokenLedger` without a cycle: the two-instruction standalone shape (`tokenLedgerInstruction` + `swapInstruction`) — the caller inserts a deposit instruction between them, and the deposited amount becomes the swap input. `/swap` rejects this combination with `INVALID_TOKEN_LEDGER_MODE`. See [`POST /swap-instruction`](api-swap-instruction).
- `executionMode=maxIn` without a cycle: a single-instruction standalone shape — one `swap_tob_v3` in Swap-Max mode as `swapInstruction` (sentinel `amount_in`, `tokenLedgerInstruction=null`, `otherInstructions=[]`) — the caller inserts their own funding instruction(s) before `swapInstruction`. `/swap` rejects this combination with `INVALID_SWAP_MODE`. See [`POST /swap-instruction`](api-swap-instruction).

With a cycle (`enableCyclicArbitrage=true`), both instead produce the A2A splits described in the table above.

> **Default-behavior note (breaking change):** this supersedes the earlier `useTokenLedger: bool` field entirely (removed from the wire format). Historically, `enableCyclicArbitrage=true` always produced the two-leg (A2A) shape; it now produces the **single whole-cycle instruction** by default. Pass `executionMode=maxIn` to get the two-leg Swap-Max split, or `executionMode=tokenLedger` for the three-instruction literal-ledger split. The single-instruction shape requires the on-chain program to support return-to-start normalization.

---

## What it does

Given a start token (say SOL) and a set of intermediate tokens, Pallas looks for the most profitable cycle that leaves and returns to SOL:

```
            ┌─────────────────────────────┐
            │                             │
   start ─► SOL ─► … intermediate … ─► SOL ─► end
            │                             │
            └──── more SOL than you put in ┘
```

The quote returns the best loop it can build over the given tokens. Note that "best" does **not** guarantee "profitable" — when no real arbitrage exists, you still get a route back, just one whose output is at or below the input. Always compare the returned `toTokenAmount` against your input `amount` before acting on it.

---

## Per-protocol uniqueness

Pallas can prevent selected DEX protocols from appearing more than once in the same loop. This protects cycles whose two legs would otherwise use different pools backed by the same protocol state. For example, if Manifest is in the effective list, `SOL → Manifest pool A → USDC → Manifest pool B → SOL` is rejected, while a loop containing one Manifest hop remains eligible.

The effective list is resolved in this order:

| Request state | Effective behavior |
|---------------|--------------------|
| `enableUniqueDex=false` | Constraint disabled; both request and Hub lists are ignored. |
| Non-empty `uniqueDexIds` | The request list replaces the Hub list; the two lists are not merged. |
| `uniqueDexIds` omitted or empty | The independently managed Hub list is used. |
| Hub list empty or not yet fetched | Constraint disabled until a non-empty list is available. |

The rule is applied while searching, so Pallas can return the best legal alternative rather than first choosing an illegal route and discarding it afterward. Protocols outside the effective list may still appear more than once. `dexIds` and `excludedDexIds` remain separate allow/deny filters: they decide whether a DEX can be used at all, while `uniqueDexIds` only limits repetition.

All IDs must be valid base58-encoded 32-byte program IDs. Validation happens before `enableUniqueDex` is applied, so an invalid `uniqueDexIds` value still returns `INVALID_DEX_ID` when the switch is `false`. In non-cyclic mode both fields have no routing effect.

When `enableJit=true`, the same rule also filters JIT alternatives: a candidate cannot introduce a second use of a managed protocol on another hop, but replacing the target hop with another pool from its own protocol remains allowed.

---

## How the intermediate tokens are used

A common assumption is that Pallas tries each intermediate token on its own — `SOL → X → SOL`, then `SOL → Y → SOL`, and so on — and returns whichever scored best. **That is not how it works.**

Intermediate tokens are treated as **nodes in a graph**, not as a checklist evaluated one by one. Pallas searches for the single most profitable cycle across *all* of them jointly — including multi-hop loops that pass through several intermediates — and returns the global best. The simple `SOL → X → SOL` shape is just one subset of what it considers.

```
  List view (NOT what happens)          Graph view (what actually happens)

  SOL ─► X ─► SOL   ?                          ┌───► X ───┐
  SOL ─► Y ─► SOL   ?                          │     │    │
  SOL ─► Z ─► SOL   ?                   SOL ◄───┤     ▼    ├───► SOL
  …each checked in isolation…                  │     Y    │
                                               └───► Z ───┘
  pick best of the list                  one search over the whole graph,
                                         any path through it can win
```

So requesting a SOL→SOL loop with 10 intermediate tokens does **not** mean 10 separate route lookups. It means one search over a 10-node graph, and the winning loop may go straight through one token or chain through several — whichever yields the most SOL.

---

## Other parameters that affect this mode

Cyclic arbitrage reuses the standard `/swap` request, but not every routing parameter applies. The ones that matter:

**Shape the search:**

| Parameter | Effect in cyclic mode |
|-----------|------------------------|
| `cyclicArbitrageIntermediateTokens` | The candidate token set the loop is searched over (your start token is always included automatically). |
| `dexIds` / `excludedDexIds` | Restrict which DEXes the loop may use. Only pools on the allowed DEXes are visible to the search, so these can change or eliminate the winning loop. |
| `uniqueDexIds` / `enableUniqueDex` | Control whether selected protocols may appear more than once in the loop. See [Per-protocol uniqueness](#per-protocol-uniqueness). |
| `maxAccounts` | Bounds the total accounts the route may touch. Longer loops cost more accounts, so a tighter limit pushes toward shorter loops (and can rule out an otherwise-better long loop). Cyclic mode reserves slightly more header accounts than a normal swap, so the usable budget is a little smaller than the raw number suggests. |

**Shape the resulting transaction (not the search):**

| Parameter | Effect in cyclic mode |
|-----------|------------------------|
| `slippagePercent` | Applied to the closing leg of the loop to derive its on-chain minimum output; the intermediate legs are not slippage-bounded. |
| `expectAmountOut` | Overrides the closing leg's expected output (the on-chain minimum basis) instead of using the quoted value. |

**Ignored in cyclic mode** — these have no effect when `enableCyclicArbitrage` is `true`:

- `directRoute` — the loop is always allowed to be multi-hop.
- `stableIntermediateTokensOnly` — use `cyclicArbitrageIntermediateTokens` to control the token set instead.
- `singleRouteOnly` — cyclic routes are always built as a single (non-split) route.

---

## Performance & recommendations

- **Cost does not grow linearly with the token count.** Adding tokens widens the search space, but the work per added token tapers off rather than stacking up one lookup per token.
- **Extra tokens rarely change the answer.** Profitable cycles tend to concentrate around a handful of high-liquidity hubs, so most additional intermediates never appear in the winning route.
- **Latency is small at modest sizes.** In our local benchmarks, around 20 intermediate tokens adds no perceptible delay (P99 on the order of a millisecond). Treat this as indicative — measure against your own deployment and traffic.

**Recommended starting point: ~20 intermediate tokens**, chosen from major liquidity hubs. This is based on on-chain arbitrage data, where profitable cycles cluster in a few well-connected tokens. You can go higher, but expand cautiously and watch your latency — the marginal benefit of more tokens drops off quickly.

### Recommended set

A ready-to-use 20-token set covering the main Solana liquidity hubs. Pass it as the `cyclicArbitrageIntermediateTokens` value (comma-separated, no spaces):

```
EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v,So11111111111111111111111111111111111111112,Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB,USD1ttGY1N17NEEHLmELoaybftRBUSErhqYiQzvEmuB,cbbtcf3aa214zXHbiAZQwf4122FBYbraNdFqgw4iMij,27G8MtK7VtTcCHkpASjSDdkWWYfoqT6ggEuKidVJidD4,7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs,J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn,SKRbvo6Gf7GondiT3BbTfuRDPqLWei4j2Qy2NPGZhW3,3NZ9JMVBmGAqocybic2c7LQCJScmgsAZ6vQqTDzcqmJh,pumpCmXqMfrsAkQ5r49WcJnRayYRqmXz6ae8H7H9Dfn,2u1tszSeqZ3qBWF3uNGPFc8TzMk2tdiwknnRMWGWjGWH,9BB6NFEcjBCtnNLFko2FqVQBq8HHM13kCyYcdQbgpump,JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN,98sMhvDwXj1RQi5c5Mndm3vPe9cBqPrbLaufMXFNMh5g,EicWvteVi2fWepEzS3FYWsnuPoP6caZfjnKqNvydLjCH,8wM2dHQFsdVC3SUxzz3ZnCMMQXHQAXwfXxjug33y7SfP,CtzPWv73Sn1dMGVU3ZtLv9yWSyUAanBni19YWDaznnkn,JuprjznTrTSp2UFa3ZBUFgwdAmtZCq4MQCwysN55USD,METvsvVRapdj9cFLzq4Tr43xK4tAjQfwX76z3n6mWQL
```

This is a suggested baseline, not a fixed list — tune it to the tokens and pools you actually trade against.

---

## Example

A SOL → … → SOL loop with a custom intermediate set:

```bash
curl -s -X POST 'http://localhost:8080/swap' \
  -H 'Content-Type: application/json' \
  -d '{
    "fromTokenAddress": "So11111111111111111111111111111111111111112",
    "toTokenAddress":   "So11111111111111111111111111111111111111112",
    "amount": "1000000000",
    "slippagePercent": "0.5",
    "userWalletAddress": "YOUR_WALLET_PUBLIC_KEY",
    "enableCyclicArbitrage": true,
    "cyclicArbitrageIntermediateTokens": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v,Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB"
  }'
```

If `cyclicArbitrageIntermediateTokens` is omitted, Pallas uses its own default intermediate set.

---

## Related notes

- When building a transaction, the returned route's instruction shape depends on `executionMode` (see [Instruction shape](#instruction-shape)): with the default `executionMode=singleTx` it is a **single** `swapInstruction` covering the whole loop (`tokenLedgerInstruction=null`, `otherInstructions=[]`); with `executionMode=maxIn` it is split into two legs (leg-1 in `swapInstruction`, leg-2 `swap_tob_v3` Swap-Max in `otherInstructions[0]`; `tokenLedgerInstruction` is always `null`); with `executionMode=tokenLedger` it is split into two legs plus a literal ledger snapshot (leg-1 in `swapInstruction`, `tokenLedgerInstruction` populated with `set_token_ledger`, leg-2 `swap_tob_with_token_ledger_v3` in `otherInstructions[0]`). For the slippage and transaction-assembly details, see [`POST /swap-instruction` → Cyclic-arbitrage slippage](api-swap-instruction#cyclic-arbitrage-slippage).
- Parameter reference: [`POST /swap`](api-swap) and [`POST /swap-instruction`](api-swap-instruction).
</content>
</invoke>
