# Error Code Reference

All error responses use a unified JSON format:

```json
{
  "errorCode": "ERROR_CODE",
  "message": "human-readable message"
}
```

Business errors return HTTP 200; system/user errors use the corresponding 4xx/5xx status codes.

# `/swap` and `/swap-instructions` Shared Error Codes

Both endpoints share parameter validation and routing logic; error codes are identical.

## Parameter Validation Errors


| HTTP | errorCode                     | Condition                                                                          |
| ---- | ----------------------------- | ---------------------------------------------------------------------------------- |
| 400  | `INVALID_SLIPPAGE`            | `slippagePercent` not in [0, 100) or is NaN                                        |
| 400  | `INVALID_AMOUNT`              | `amount` is 0                                                                      |
| 400  | `INVALID_WALLET`              | `userWalletAddress` is empty, invalid base58, or not 32 bytes after decoding       |
| 400  | `INVALID_CYCLE_ARBITRAGE`     | `enableCyclicArbitrage=true` but `fromTokenAddress != toTokenAddress`              |
| 400  | `INVALID_TOKEN_PAIR`          | `fromTokenAddress == toTokenAddress` but `enableCyclicArbitrage=false`             |
| 400  | `MISSING_INTERMEDIATE_TOKENS` | `enableCyclicArbitrage=true` but `cyclicArbitrageIntermediateTokens` not provided  |
| 400  | `INVALID_INTERMEDIATE_TOKEN`  | `cyclicArbitrageIntermediateTokens` contains invalid base58 or not 32 bytes        |
| 400  | `INVALID_DEX_ID`              | `dexIds` / `excludedDexIds` contains invalid base58 or not 32 bytes after decoding |
| 400  | `INVALID_POSITIVE_SLIPPAGE_PAIR`      | `positiveSlippageReceiverAddress` and `positiveSlippageBps` must be supplied together (XOR — both `Some` or both `None`) |
| 400  | `INVALID_POSITIVE_SLIPPAGE_BPS`       | `positiveSlippageBps` outside the `[0, 1000]` range (contract `TRIM_RATE_LIMIT = 100`, i.e. ≤ 10%)                       |
| 400  | `INVALID_POSITIVE_SLIPPAGE_BPS_PRECISION` | `positiveSlippageBps > 0` but not a multiple of `10` (contract `TRIM_DENOMINATOR = 1_000` only resolves 0.1% steps)  |
| 400  | `INVALID_POSITIVE_SLIPPAGE_RECEIVER`  | `positiveSlippageReceiverAddress` is empty, invalid base58, or not 32 bytes after decoding                                |
| 400  | `INVALID_EXPECT_AMOUNT_OUT`           | `expectAmountOut` is `"0"` (a zero override would disable on-chain slippage protection). Omitting the field or sending `null` is accepted. |


## Routing Errors


| HTTP | errorCode                 | Category | Condition                   |
| ---- | ------------------------- | -------- | --------------------------- |
| 200  | `NO_ROUTES_FOUND`         | Business | No available routes found   |
| 200  | `TOKEN_NOT_TRADABLE`      | Business | Token is not tradable       |
| 200  | `AMOUNT_TOO_SMALL`        | Business | Input amount too small      |
| 200  | `AMOUNT_TOO_LARGE`        | Business | Input amount too large      |
| 200  | `EXACT_OUT_NOT_SUPPORTED` | Business | Exact-out not supported     |
| 404  | `MARKET_NOT_FOUND`        | System   | Market not found            |
| 400  | `MAX_ACCOUNTS_EXCEEDED`   | System   | Exceeds `maxAccounts` limit |
| 500  | `INTERNAL_ERROR`          | System   | Internal error              |


## Transaction Building Errors


| HTTP | errorCode               | Category       | Condition                                                          |
| ---- | ----------------------- | -------------- | ------------------------------------------------------------------ |
| 200  | `SLIPPAGE_EXCEEDED`     | Business       | Slippage limit exceeded                                            |
| 200  | `BLOCKHASH_EXPIRED`     | Business       | Blockhash has expired                                              |
| 200  | `BUILD_FAILED`          | Business       | Transaction build failed                                           |
| 200  | `TRANSACTION_TOO_LARGE` | Business       | Transaction exceeds 1232 bytes; retry with a smaller `maxAccounts` |
| 400  | `INSUFFICIENT_FUNDS`    | User           | Insufficient funds                                                 |
| 200  | `BLOCKHASH_UNAVAILABLE` | Business       | Blockhash cache unavailable                                        |
| 501  | `NOT_IMPLEMENTED`       | System         | Feature not implemented                                            |


## Service-Level Errors


| HTTP | errorCode              | Condition                                                    |
| ---- | ---------------------- | ------------------------------------------------------------ |
| 503  | `SERVICE_UNAVAILABLE`  | System not ready (has not entered Normal state)              |
| 400  | `CHAIN_NOT_CONFIGURED` | chain_id not registered (should not occur on normal startup) |


# `/program-id-to-label` Error Codes


| HTTP | errorCode | Condition                                         |
| ---- | --------- | ------------------------------------------------- |
| 504  | `TIMEOUT` | Request processing exceeded 10ms internal timeout |


# `/evict-pools` Error Codes


| HTTP | errorCode              | Condition                            |
| ---- | ---------------------- | ------------------------------------ |
| 400  | `INVALID_REQUEST`      | Empty `pools` array or > 1000 items  |
| 400  | `CHAIN_NOT_CONFIGURED` | Unknown `chainId`                    |
| 400  | `CHAIN_NOT_SUPPORTED`  | Chain does not support pool eviction |
