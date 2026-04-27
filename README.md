# Pallas Self-Host

Self-hosted Solana DEX aggregator quote service by OKX. Pallas subscribes to on-chain AMM pool states, computes optimal multi-hop swap routes locally, and exposes HTTP APIs for quotes and transaction building.

## Prerequisites

- **OKX API credentials** — API Key, Secret Key, and Passphrase ([create here](https://web3pre.okex.org/zh-hans/onchainos/dev-portal))
- **Solana RPC endpoint** — a dedicated RPC node is recommended
- **Geyser gRPC endpoint** — Yellowstone or Richat, for real-time on-chain data streaming (strongly recommended for production)
- **Hardware** — 8 cores / 16 GB RAM / 100 GB SSD recommended

## Quick Start

### Option 1: Run Binary Directly (recommended)

Download the pre-compiled binary from [GitHub Releases](https://github.com/okx/dex-solana-binary/releases):

| Platform | File |
|----------|------|
| Linux x86_64 | `pallas-x86_64-unknown-linux-gnu.tar.gz` |
| macOS ARM64 | `pallas-aarch64-apple-darwin.tar.gz` |

```bash
# Download and extract (example: Linux x86_64)
tar -xzf pallas-x86_64-unknown-linux-gnu.tar.gz

# Create .env file
cat <<EOF > .env
OKX_API_KEY=<your-api-key>
OKX_SECRET_KEY=<your-secret-key>
OKX_PASSPHRASE=<your-passphrase>
RPC_URL=<your-solana-rpc-url>
GEYSER_ENDPOINT=<your-geyser-grpc-endpoint>
GEYSER_X_TOKEN=<your-geyser-token>
EOF

# Run
source .env && ./pallas
```

Run `./pallas --help` for all available configuration options.

> **macOS users:** If you see a security warning, go to **System Settings > Privacy & Security** and click **Allow Anyway**.

### Option 2: Docker Compose

```bash
git clone https://github.com/okx/dex-solana-binary.git
cd dex-solana-binary
cp .env.example .env
# Edit .env — fill in your credentials, RPC URL, and Geyser endpoint
docker compose up -d
```

Check readiness:

```bash
curl http://localhost:9100/ready
```

## API Reference

### Business API (default port 8080)

| Endpoint | Description |
|----------|-------------|
| `POST /swap` | Returns a swap transaction |
| `POST /swap-instructions` | Returns swap instructions for custom transaction composition |

For full API documentation, see [API Docs](TODO).

### Health & Metrics (default port 9100)

```bash
curl http://localhost:9100/health     # Liveness check
curl http://localhost:9100/ready      # Readiness check — 200 means service is ready
curl http://localhost:9100/status     # Current system state and sync progress
curl http://localhost:9100/metrics    # Prometheus-format metrics
```

## System States

After startup, the service syncs on-chain state before serving traffic. Use `GET /status` to check the current state. When it reaches **Normal**, `GET /ready` returns 200 and the service is ready to accept requests.

## Configuration

Required environment variables are listed in `.env.example`. For all available options including threading, gRPC tuning, market configuration, and logging, run:

```bash
./pallas --help
```

## Troubleshooting

### /ready returns 503

This is normal during startup. The service needs time to sync on-chain state. Check `GET /status` to monitor progress. Typical startup time depends on your RPC/gRPC connection speed.

### High RPC load

If your RPC node is under heavy load, use a Geyser gRPC endpoint (`GEYSER_ENDPOINT`) for real-time on-chain data streaming. This significantly reduces RPC polling pressure.

### macOS security warning

When running the binary on macOS, you may see "cannot be opened because the developer cannot be verified." Go to **System Settings > Privacy & Security** and click **Allow Anyway**, then run the binary again.

---

Copyright (c) 2025 OKX. All rights reserved.
