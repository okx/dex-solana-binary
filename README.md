# Glossary

For key terms (Geyser, Geyser gRPC, Yellowstone, Richat, AMM), see [Glossary](docs/glossary.md).

# Overview

Pallas is an OKX-built DEX aggregator client deployed on user infrastructure, providing on-chain AMM quoting and transaction building.

Core capabilities:

- Real-time on-chain AMM pool state via gRPC (Geyser) streaming + RPC polling
- Local multi-hop optimal route computation and transaction building
- [Cyclic arbitrage routing](docs/cyclic-arbitrage.md) — find the most profitable round-trip (same token in and out) across a set of intermediate tokens
- HTTP API endpoints (`/swap`, `/swap-instruction`, etc.)
- Prometheus monitoring metrics

# Prerequisites

- OKX **API Key**, **Secret Key**, and **Passphrase** (for HMAC signature authentication) **[Apply here for whitelist](https://form.typeform.com/to/k0Axsial)**
- A Solana RPC endpoint
- Recommended: a Geyser gRPC endpoint (Yellowstone or Richat) to significantly reduce RPC node load and improve data freshness
- Download the Pallas binary **[Download](https://github.com/okx/dex-solana-binary/releases)**
- Hardware requirements: recommended 8 cores / 16 GB RAM / 100 GB SSD

# Quick Start

## Option 1: Run the Binary Directly

With gRPC streaming (recommended):

```bash
LOG_LEVEL=info ./pallas \
  --okx-api-key YOUR_API_KEY \
  --okx-secret-key YOUR_SECRET_KEY \
  --okx-passphrase YOUR_PASSPHRASE \
  --rpc-url YOUR_RPC_URL \
  --grpc-endpoint YOUR_GRPC_ENDPOINT \
  --grpc-x-token YOUR_X_TOKEN
```

With RPC polling only (higher node load, not recommended):

```bash
LOG_LEVEL=info ./pallas \
  --okx-api-key YOUR_API_KEY \
  --okx-secret-key YOUR_SECRET_KEY \
  --okx-passphrase YOUR_PASSPHRASE \
  --rpc-url YOUR_RPC_URL
```

### CLI Short Flags

Commonly used flags support short forms:

| Short | Long | Env Var | Description |
|-------|------|---------|-------------|
| `-H` | `--host` | `HOST` | HTTP API bind address |
| `-p` | `--port` | `PORT` | HTTP API listen port |
| `-e` | `--grpc-endpoint` | `GEYSER_GRPC_ENDPOINT` | Geyser gRPC endpoint |
| `-x` | `--grpc-x-token` | `GEYSER_GRPC_X_TOKEN` | Geyser gRPC auth token |

## Option 2: Use an Environment File

Create a `.env` file with the required parameters:

```bash
OKX_API_KEY=<your-api-key>
OKX_SECRET_KEY=<your-secret-key>
OKX_PASSPHRASE=<your-passphrase>
RPC_URL=<your-solana-rpc-url>
GEYSER_GRPC_ENDPOINT=<your-geyser-grpc-endpoint>
GEYSER_GRPC_X_TOKEN=<your-geyser-token>
```

Start:

```bash
./pallas --env-file .env
```

## Option 3: Docker Compose

```bash
git clone https://github.com/okx/dex-solana-binary.git
cd dex-solana-binary
# Create .env file as shown in Option 2 above
docker compose up -d
```

## Verify Startup

After starting Pallas (any option above), wait for it to reach the Normal state:

```bash
# Check readiness (returns 200 when ready, 503 otherwise)
curl http://localhost:9100/ready

# Monitor loading progress
curl http://localhost:9100/status
```

Startup typically takes several minutes while Pallas loads market data and syncs on-chain state.

# HTTP Services

Pallas starts two independent HTTP services:

- **Business API** (default `0.0.0.0:8080`): quoting and transaction building endpoints
- **Ops Metrics** (default `127.0.0.1:9100`): health checks, readiness probes, and monitoring endpoints. Set `METRICS_BIND=0.0.0.0` for external access

## Business API Endpoints (PORT, default 8080)


| Endpoint               | Method | Description                                                                                                        |
| ---------------------- | ------ | ------------------------------------------------------------------------------------------------------------------ |
| `/swap`                | POST   | Quote + transaction building                                                                                       |
| `/swap-instruction`   | POST   | Quote + decomposed instructions for caller-assembled transactions                                                  |
| `/program-id-to-label` | GET    | DEX program ID to protocol name mapping                                                                            |
| `/evict-pools`         | POST   | Ops endpoint: evict specified pools from all caches and routing, persisted to runtime denylist (survives restarts) |


## Ops Endpoints (METRICS_PORT, default 9100)


| Endpoint   | Method | Description                                                                     |
| ---------- | ------ | ------------------------------------------------------------------------------- |
| `/health`  | GET    | Liveness probe, always returns 200                                              |
| `/ready`   | GET    | Readiness probe, returns 200 when ready, 503 otherwise                          |
| `/status`  | GET    | Runtime diagnostics (version, state, sanitized config snapshot, dynamic config) |
| `/metrics` | GET    | Prometheus metrics (text exposition format)                                     |


## API Reference

The core business endpoints are `/swap` and `/swap-instruction`. For detailed request parameters, response structures, and examples, see:

- [POST /swap](docs/api-swap.md) — Quote + transaction building (request parameters, response fields, examples)
- [POST /swap-instruction](docs/api-swap-instruction.md) — Quote + decomposed instructions (assembly order, cycle arbitrage)
- [Cyclic Arbitrage Mode](docs/cyclic-arbitrage.md) — round-trip routing: how `enableCyclicArbitrage` and `cyclicArbitrageIntermediateTokens` work, and sizing recommendations
- [GET /program-id-to-label](docs/api-program-id-to-label.md) — DEX program ID to protocol name mapping
- [POST /evict-pools](docs/api-evict-pools.md) — Runtime pool eviction
- **[Error Code Reference](docs/api-errors.md)** — Unified error codes for all endpoints

# Configuration

For all configuration options, see [Configuration](docs/configuration.md).

# System State

`/ready` endpoint and `/status` endpoint return the current system state. When it returns Normal, the service is ready to use.

```bash
curl http://localhost:9100/ready
curl http://localhost:9100/status
```

State changes can also be monitored via the `system_state` gauge in `/metrics`.

# Support

For troubleshooting, FAQ, and support, see [Troubleshooting, FAQ & Support](docs/support.md).