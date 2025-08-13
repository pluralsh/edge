#!/bin/bash
# Vendor K3s assets for offline deployment

set -e

# Configuration with defaults
OUTPUT_DIR="${OUTPUT_DIR:-./assets}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -v, --version VERSION   K3s version (default: ${K3S_VERSION})"
    echo "  -a, --arch ARCH         Architecture (default: ${ARCH})"
    echo "  -o, --output DIR        Output directory (default: ${OUTPUT_DIR})"
    echo "  -h, --help              Show this help"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            K3S_VERSION="$2"
            shift 2
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

k3s::binary::name() {
    local arch="$1"
    case "$arch" in
        x86_64|amd64) echo "k3s" ;;
        aarch64|arm64) echo "k3s-arm64" ;;
        armv7l) echo "k3s-armhf" ;;
        *) echo "unknown" && exit 1 ;;
    esac
}

echo "Vendoring K3s ${K3S_VERSION} for ${ARCH} to ${OUTPUT_DIR}..."

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Download K3s binary
K3S_BINARY_NAME=$(k3s::binary::name "${ARCH}")
echo "Downloading K3s binary..."
wget -O "${OUTPUT_DIR}/${K3S_BINARY_NAME}" \
    "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/${K3S_BINARY_NAME}"
chmod +x "${OUTPUT_DIR}/${K3S_BINARY_NAME}"

# Download K3s install script
echo "Downloading K3s install script..."
wget -O "${OUTPUT_DIR}/install.sh" https://get.k3s.io/
chmod +x "${OUTPUT_DIR}/install.sh"

# Download K3s airgap images
echo "Downloading K3s airgap images..."
wget -O "${OUTPUT_DIR}/k3s-airgap-images-${ARCH}.tar.gz" \
    "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images-${ARCH}.tar.gz"

echo "K3s vendoring complete!"
echo "Assets saved to: ${OUTPUT_DIR}"