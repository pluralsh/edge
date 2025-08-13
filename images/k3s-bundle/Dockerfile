FROM debian:13-slim AS builder

# Install required tools
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set versions and architecture
ARG K3S_VERSION=v1.32.0+k3s1
ARG TARGETARCH

WORKDIR /build

# Copy vendoring script
COPY vendor-k3s.sh .
RUN chmod +x vendor-k3s.sh

RUN K3S_VERSION=${K3S_VERSION} ARCH=${TARGETARCH} OUTPUT_DIR=/assets ./vendor-k3s.sh

# Final stage - only assets
FROM --platform=$BUILDPLATFORM scratch

COPY --from=builder /assets/ /assets