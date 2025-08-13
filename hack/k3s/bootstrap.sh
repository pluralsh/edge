#!/bin/bash

set -e

current_arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "arm" ;;
        *)
          echo "unknown"
          exit 1
          ;;
    esac
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/assets"
K3S_ASSETS_DIR="${ASSETS_DIR}/k3s"
PLURAL_ASSETS_DIR="${ASSETS_DIR}/plural"
PLURAL_IMAGES_ASSETS_DIR="${ASSETS_DIR}/plural-images"
PLURAL_TRUST_MANAGER_ASSETS_DIR="${ASSETS_DIR}/plural-trust-manager"


# K3s configuration
K3S_LOCAL_IMAGES_DIR="/var/lib/rancher/k3s/agent/images"
K3S_VERSION=${K3S_VERSION:-"1.32.0"}
ARCH=$(current_arch)

# Bundle images configuration
K3S_BUNDLE_IMAGE="ghcr.io/pluralsh/kairos-k3s-bundle:${K3S_VERSION}"
PLURAL_BUNDLE_IMAGE="ghcr.io/pluralsh/kairos-plural-bundle:1.0.0"
PLURAL_IMAGES_BUNDLE_IMAGE="ghcr.io/pluralsh/kairos-plural-images-bundle:0.2.0"
PLURAL_TRUST_MANAGER_BUNDLE_IMAGE="ghcr.io/pluralsh/kairos-plural-trust-manager-bundle:1.0.0"

download_assets_from_oci() {
    local oci_image="${1}"
    local assets_dir="${2}"
    local temp_dir=$(mktemp -d)
    local container_name="assets-$$"

    if [ -z "${oci_image}" ]; then
        echo "No OCI image specified"
        rm -rf "${temp_dir}"
        exit 1
    fi

    if [ -z "${assets_dir}" ]; then
        echo "No assets directory specified"
        rm -rf "${temp_dir}"
        exit 1
    fi

    echo "Downloading assets from OCI registry: ${oci_image}"

    # Create assets directory if it doesn't exist
    mkdir -p "${assets_dir}"

    if command -v docker >/dev/null 2>&1; then
        echo "Using docker to extract assets..."
        # Create container without running it (scratch images can't execute commands)
        docker create --name "${container_name}" "${oci_image}" true || {
            echo "Failed to create container from OCI image"
            rm -rf "${temp_dir}"
            exit 1
        }

        # Copy assets directory from container
        docker cp "${container_name}:/assets/." "${temp_dir}/" || {
            echo "Failed to copy assets from container"
            docker rm "${container_name}" >/dev/null 2>&1
            rm -rf "${temp_dir}"
            exit 1
        }

        # Remove container
        docker rm "${container_name}" >/dev/null 2>&1
    else
        echo "Docker not found. Cannot download assets from OCI registry."
        rm -rf "${temp_dir}"
        exit 1
    fi

    # Copy extracted assets to assets directory
    cp -r "${temp_dir}"/* "${assets_dir}/"

    # Cleanup
    rm -rf "${temp_dir}"

    echo "Assets downloaded successfully from OCI registry to ${assets_dir}"
}

# Function to check if asset exists locally
check_local_asset() {
    local asset_path="$1"
    if [ -f "${ASSETS_DIR}/${asset_path}" ]; then
        echo "Using local asset: ${asset_path}"
        return 0
    else
        echo "Local asset not found: ${asset_path}"
        return 1
    fi
}

vendor() {
    target="${1}"

    if [ -z "${target}" ]; then
        echo "Usage: vendor <target>"
        exit 1
    fi

    case "${target}" in
        k3s)
            vendor::k3s
            ;;
        *)
            echo "Unknown vendor target: ${target}"
            exit 1
            ;;
    esac
}

vendor::k3s() {
    local assets_missing=false

    if ! check_local_asset "k3s-${ARCH}" >/dev/null 2>&1; then
        assets_missing=true
    fi

    if ! check_local_asset "k3s-airgap-images-${ARCH}.tar.gz" >/dev/null 2>&1; then
        assets_missing=true
    fi

    if ! check_local_asset "install.sh" >/dev/null 2>&1; then
        assets_missing=true
    fi

    if [ "$assets_missing" = true ]; then
        echo "Some K3s assets are missing, downloading..."
        download_assets_from_oci "${K3S_BUNDLE_IMAGE}" "${K3S_ASSETS_DIR}"
    fi
}

install::k3s() {
    local k3s_version="${1}"
    local arch="${2}"

    if [ -z "${k3s_version}" ]; then
        echo "K3s version not specified"
        exit 1
    fi

    if [ -z "${arch}" ]; then
        echo "Architecture not specified"
        exit 1
    fi

    echo "Installing K3s version ${k3s_version} for architecture ${arch}..."

    # Install K3s binary
    sudo cp "${ASSETS_DIR}/k3s-${ARCH}" /usr/local/bin/k3s
    sudo chmod +x /usr/local/bin/k3s

    # Setup K3s directories
    sudo mkdir -p "${LOCAL_IMAGES_DIR}"

    # Handle airgap images
    sudo cp "${ASSETS_DIR}/k3s-airgap-images-${ARCH}.tar.gz" "${K3S_LOCAL_IMAGES_DIR}/"

    # Get install script
    cp "${ASSETS_DIR}/install.sh" /tmp/install.sh
    chmod +x /tmp/install.sh

    # Install K3s
    export INSTALL_K3S_SKIP_DOWNLOAD=true
    export INSTALL_K3S_EXEC="--node-name=plural --embedded-registry --disable=traefik,servicelb"
    export K3S_KUBECONFIG_MODE="644"

    echo "Installing K3s..."
    sudo -E /tmp/install.sh

    # Cleanup
    rm -f /tmp/install.sh

    # Wait for K3s to start with continuous checking
    echo "Waiting for K3s to start..."
    local max_attempts=60  # 5 minutes timeout
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if sudo k3s kubectl get nodes >/dev/null 2>&1; then
            echo "K3s is ready!"
            break
        fi

        echo "K3s not ready yet, waiting... (attempt $((attempt + 1))/${max_attempts})"
        sleep 5
        attempt=$((attempt + 1))
    done

    if [ $attempt -eq $max_attempts ]; then
        echo "Timeout: K3s failed to start within 5 minutes"
        exit 1
    fi

    echo "K3s installation complete!"
    echo "Kubeconfig: /etc/rancher/k3s/k3s.yaml"
}

# Vendor assets if needed
vendor k3s

# Install K3s
install::k3s "${K3S_VERSION}" "${ARCH}"