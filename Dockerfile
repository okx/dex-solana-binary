FROM --platform=linux/amd64 debian:bookworm-slim

ARG VERSION=latest

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fSL "https://github.com/okx/dex-solana-binary/releases/download/${VERSION}/pallas-x86_64-unknown-linux-gnu.tar.gz" \
    -o /tmp/pallas.tar.gz && \
    tar -xzf /tmp/pallas.tar.gz -C /usr/local/bin/ && \
    rm /tmp/pallas.tar.gz && \
    chmod +x /usr/local/bin/pallas

RUN useradd -r -s /bin/false pallas
USER pallas

ENV RUST_LOG=info

EXPOSE 8080 9100

ENTRYPOINT ["pallas"]
