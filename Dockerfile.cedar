# Dockerfile for Cedar CLI - optimized for fast builds
FROM rust:1.75-slim as builder

# Install Cedar CLI in builder stage
RUN cargo install --locked cedar-policy-cli --version 4.4.1

# Final stage - minimal image
FROM debian:bookworm-slim

# Copy Cedar binary from builder
COPY --from=builder /usr/local/cargo/bin/cedar /usr/local/bin/cedar

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Verify installation
RUN cedar --version

# Set working directory
WORKDIR /workspace

# Default command
CMD ["cedar", "--help"]