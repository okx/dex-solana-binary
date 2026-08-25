# Troubleshooting

## macOS Security Prompt

When running the binary on macOS, the system may block it. To resolve:

1. Open **System Settings**
2. Go to **Privacy & Security**
3. Click **Open Anyway**

## Runtime Pool Eviction

When a DEX pool behaves abnormally (incorrect quotes, sudden liquidity changes, etc.) and needs to be immediately taken out of rotation, use `POST /evict-pools` to dynamically evict it without restarting Pallas. For API details, see [POST /evict-pools](api-evict-pools.md).

Eviction flow:

- Immediately removes the specified pool from all in-memory caches (pool metadata / token-to-markets index / account-to-pools / pool_tick_watchset / alt-to-pools / pool_slots / algorithm topology)
- Automatically detects orphaned ALTs and unsubscribes from gRPC; ALTs still referenced by other pools are retained
- Writes to the persistent runtime denylist file (`${BLOCKED_POOLS_RUNTIME_FILE}`), effective across restarts
- All subsequent reload paths (biz_tick incremental pushes, reconnection recovery, soft sync, etc.) skip denylisted pools

This endpoint is currently unauthenticated; access control is handled at the deployment layer via network policies / reverse proxy ACLs.

Monitoring metrics:


| Metric                                      | Type    | Description                                                                                                                       |
| ------------------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `pallas_evicted_pools_total{source,result}` | counter | `source` in {`startup`,`runtime`}, `result` in {`evicted`,`not_found`,`invalid`}. Aggregates startup filtering + runtime eviction |
| `pallas_blocked_pools_size`                 | gauge   | Current effective denylist size (startup union runtime)                                                                           |


**Restoring an evicted pool:** There is currently no unblock endpoint. To restore a pool, edit `${BLOCKED_POOLS_RUNTIME_FILE}` and/or the `BLOCKED_POOLS` environment variable, then restart Pallas.

## Built-in Checker (--check)

Run `pallas --check` (or `-c`) to execute 8 diagnostic checks and exit without starting the main service. Useful for first-deploy validation or diagnosing runtime issues.

```bash
./pallas-darwin-aarch64 --env-file .env --check
./pallas-darwin-aarch64 -c
```

### Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | All checks PASS (SKIP is neutral) | Safe to start |
| 1 | At least one WARN, no FAIL | Proceed with caution |
| 2 | At least one FAIL | Investigate before starting |
| 3 | Checker cannot start (config unreadable) | Fix .env / environment |

### Checks Performed

**A-Zone (always run):**
1. Environment baseline — OS, arch, CPU cores, total memory (WARN if < 6 GB)
2. Config integrity — required fields, URL format, API key length
3. Network reachability — Hub HTTP, Hub gRPC, Solana RPC, Geyser gRPC (4 parallel probes)
4. Hub authentication — HMAC-signed request to verify API key validity
5. Port occupancy — checks configured ports for conflicts and identifies existing Pallas instances

**B-Zone (only when a local Pallas instance is detected on configured ports):**
6. Ready probe — `/ready` endpoint status
7. Startup phase — current loading phase via `/metrics`
8. Data coverage — pool count and DEX protocol count thresholds

### Integration Examples

```bash
# systemd ExecStartPre (block startup on FAIL)
ExecStartPre=/opt/pallas/pallas --check
ExecStartPre=/bin/sh -c 'test $? -le 1'

# k8s initContainer
command: ["./pallas", "--check"]
```

### Sensitive Data

All output is redacted: home directory paths, URL credentials, query parameters, and standalone tokens (16+ chars) are masked automatically. Terminal output uses ANSI color when connected to a TTY.

# FAQ

**`/ready` returns 503 after startup**

This is expected. Pallas needs to load market data and account state after starting, which typically takes several minutes before entering the Normal state. Check loading progress via `/status` on the ops port (default 9100).

**Excessive RPC node load**

- Use gRPC streaming mode instead of RPC polling (configure `GEYSER_GRPC_ENDPOINT`)

**"Authentication failed" or "Invalid passphrase"**

The passphrase is the one you set when creating the API Key on the OKX Dev Portal, not your wallet password or OKX account password.

**"Forbidden" or API Key not working**

After creating an API Key, ensure the required permissions and IP whitelist are configured on the OKX Dev Portal.

**429 Too Many Requests from RPC node**

Free-tier RPC nodes have rate limits. Occasional 429 warnings during startup are normal — Pallas respects `RPC_MAX_CONCURRENT_REQUESTS` (default 50) to cap concurrent RPC calls, and will automatically retry. If 429 errors persist, consider using a paid RPC endpoint or reducing `RPC_MAX_CONCURRENT_REQUESTS` (e.g. to 10-20).

# Feedback & Support

For other issues or assistance, visit the GitHub repository to check existing issues or submit a new one:

[https://github.com/okx/dex-solana-binary](https://github.com/okx/dex-solana-binary)
