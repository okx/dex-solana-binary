# Configuration

All parameters can be configured via CLI flags (`--flag-name`) or environment variables.

CLI flag names follow the pattern: `FOO_BAR_BAZ` -> `--foo-bar-baz`. For example, `RPC_MAX_CONCURRENT_REQUESTS` can be set via `--rpc-max-concurrent-requests 100`. Run `pallas --help` for a complete list.

## Authentication


| Env Var          | Default      | Description                                       |
| ---------------- | ------------ | ------------------------------------------------- |
| `OKX_API_KEY`    | **Required** | API Key (AK) for HMAC signature authentication **[Apply here for whitelist](https://form.typeform.com/to/k0Axsial)**   |
| `OKX_SECRET_KEY` | **Required** | Secret Key (SK) for HMAC signature authentication **[Apply here for whitelist](https://form.typeform.com/to/k0Axsial)**|
| `OKX_PASSPHRASE` | **Required** | Passphrase for OKX AK authentication              |


## Service & Connectivity


| Env Var                  | Default      | Description                                                                                                                                                                                                   |
| ------------------------ | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PORT`                   | `8080`       | Business API listen port                                                                                                                                                                                      |
| `METRICS_PORT`           | `9100`       | Ops Metrics listen port (/health, /ready, /status, /metrics)                                                                                                                                                  |
| `METRICS_BIND`           | `127.0.0.1`  | Ops Metrics bind address. Set to `0.0.0.0` for external access (e.g. Prometheus scraping)                                                                                                                     |
| `RPC_URL`                | **Required** | Solana RPC endpoint                                                                                                                                                                                           |
| `GEYSER_GRPC_ENDPOINT`   | Not set      | Geyser gRPC streaming endpoint                                                                                                                                                                                |
| `GEYSER_GRPC_X_TOKEN`    | Not set      | Geyser gRPC authentication token                                                                                                                                                                              |
| `GEYSER_MODE`            | `auto`       | `auto` / `yellowstone` / `richat` / `rpc-only`. In auto mode, probes the gRPC endpoint with `GetVersion` to detect Richat vs Yellowstone; probe failure falls back to Yellowstone. If no gRPC endpoint is set, falls back to RPC polling. Specifying yellowstone or richat requires `GEYSER_GRPC_ENDPOINT` |
| `GEYSER_GRPC_COMMITMENT` | `processed`  | Commitment level for gRPC subscriptions and RPC fallback. Valid values: `processed` / `confirmed` / `finalized` (case-insensitive)                                                                            |
| `GEYSER_GRPC_COMPRESSION`| `gzip`       | gRPC compression mode for Yellowstone / Richat subscription streams. Valid values: `none` / `gzip` / `zstd` (case-insensitive). Applied symmetrically to send and accept. Ignored in `rpc-only` mode.        |
| `SHUTDOWN_TIMEOUT_SECS`  | `1`          | Graceful shutdown timeout (seconds)                                                                                                                                                                           |
| `HOST`                        | `0.0.0.0`   | Business API bind address                                                                                                                                                                                |
| `RPC_MAX_CONCURRENT_REQUESTS` | `100` | Max concurrent RPC `getMultipleAccounts` batch requests across both pools (engine fast-lane + pipeline). Raised from 50 to 100 so AIMD has more ceiling headroom; AIMD still throttles back via on_error when endpoint actually thrashes. Set to `0` to enable pure adaptive concurrency. |
| `RPC_POLL_INTERVAL_MS`   | `200`        | Polling interval in milliseconds (RPC-only mode)                                                                                                                                                              |


## gRPC Streaming Tuning


| Env Var                                | Default | Description                                                               |
| -------------------------------------- | ------- | ------------------------------------------------------------------------- |
| `GEYSER_STREAMING_CHUNK_COUNT`         | `12`    | Number of parallel gRPC streams                                           |
| `GEYSER_GRPC_RECV_TIMEOUT`             | `60000` | Message receive timeout (ms); disconnects and reconnects on timeout       |
| `GEYSER_GRPC_CONNECT_TIMEOUT_MS`       | `10000` | Connection establishment timeout (ms)                                     |
| `GEYSER_GRPC_MAX_MESSAGE_DELAY`        | `10`    | Maximum allowed message delay (seconds); disconnects if exceeded          |
| `GEYSER_GRPC_RESET_ON_GAP`             | `300`   | Stream gap threshold (seconds) to trigger full RPC backfill; 0 to disable |
| `GEYSER_GRPC_CHANNEL_UPDATE_CAPACITY`  | `16384` | Internal channel capacity for account updates                             |
| `GRPC_CONSISTENCY_CHECK_INTERVAL_SECS` | `30`    | Consistency check interval (seconds)                                      |
| `YELLOWSTONE_FLUSH_INTERVAL_SECS`      | `120`   | Yellowstone mode: flush interval for pending subscription diffs. Raised from 30 to 120 so always-reset RPC backfill (25-32s on busy endpoints) can complete before the next flush triggers another reconnect; trade-off is newly-added pools wait up to 60s on average before being gRPC-subscribed (no data loss — biz_tick added-pool path still backfills inline). |
| `RICHAT_MAX_PUBKEYS_PER_FILTER`        | `100`   | Max pubkeys per account filter (must be > 0). Richat enforces it as a server limit; Yellowstone uses it to split a large shard subscription into multiple account filters inside one full `SubscribeRequest` |
| `RICHAT_MAX_FILTERS_PER_SUBSCRIBE`     | `10`    | Richat mode only: max filters per subscribe request (must be >= 2)        |
| `SOFT_RECONNECT_TIMEOUT_SECS`         | `600`   | Soft-reconnect timeout (seconds); also caps HardReconnecting wait. Raised from 120 to 600 so transient pipeline thrash can self-heal on stale cache before triggering a full 73k+ pool rebuild |
| `SLOT_FRESHNESS_THRESHOLD`             | `50`    | Max allowed slot lag during startup readiness gate                         |
| `SLOT_FRESHNESS_TIMEOUT_SECS`          | `30`    | Max wait time (seconds) for slot freshness gate at startup                |
| `GEYSER_AUTO_DETECT_TIMEOUT_MS`        | `2000`  | Geyser auto-detect timeout (ms)                                           |


## Threading & Performance


| Env Var            | Default    | Description                       |
| ------------------ | ---------- | --------------------------------- |
| `API_THREADS`      | `0` (auto) | API service thread count          |
| `PIPELINE_THREADS` | `0` (auto) | Data pipeline thread count        |
| `ROUTE_THREADS`    | `0` (auto) | Route computation Rayon pool size |


Each parameter is evaluated independently. When set to `0`, auto-allocation follows this table:


| CPU Cores | API | Pipeline | Route                                        |
| --------- | --- | -------- | -------------------------------------------- |
| <= 8      | 2   | 2        | (cpus - API - Pipeline) / chain_count, min 1 |
| > 8       | 4   | 4        | (cpus - API - Pipeline) / chain_count, min 1 |


## Market Data


| Env Var                | Default  | Description                                                                                                                                                                                     |
| ---------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ALLOWED_TOKEN_MINTS`  | Not set  | Token mint allowlist, comma-separated. Loads all if not set                                                                                                                                     |
| `BLOCKED_DEX_PROGRAMS` | Not set  | DEX program ID denylist, comma-separated                                                                                                                                                        |
| `ALLOWED_DEX_PROGRAMS` | Not set  | DEX program ID allowlist, comma-separated. Loads all if not set                                                                                                                                 |
| `BLOCKED_POOLS`        | Not set  | Startup pool denylist, comma-separated base58 pool addresses. Matched pools are excluded from all caches; invalid entries are skipped with a warning. Use `POST /evict-pools` to add at runtime |


## Data Directory


| Env Var                      | Default                                         | Description                                                                                                                                                           |
| ---------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PALLAS_DATA_DIR`            | `./data`                                        | Pallas persistent data directory. Currently stores the runtime pool denylist file. Auto-created on first write                                                        |
| `BLOCKED_POOLS_RUNTIME_FILE` | `${PALLAS_DATA_DIR}/blocked_pools_runtime.json` | Full path to the runtime pool denylist file. Written atomically (tmp + rename) after each successful `POST /evict-pools` call; merged with `BLOCKED_POOLS` on restart |


## Observability


| Env Var     | Default | Description                                      |
| ----------- | ------- | ------------------------------------------------ |
| `LOG_LEVEL` | `info`  | Log level (e.g. `info`, `debug`)                 |
| `LOG_JSON`  | `false` | JSON-formatted log output                        |
