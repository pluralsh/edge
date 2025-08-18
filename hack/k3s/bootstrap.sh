#!/bin/env sh

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/assets"
K3S_ASSETS_DIR="${ASSETS_DIR}/k3s"
PLURAL_ASSETS_DIR="${ASSETS_DIR}/plural"
PLURAL_IMAGES_ASSETS_DIR="${ASSETS_DIR}/plural-images"
PLURAL_TRUST_MANAGER_ASSETS_DIR="${ASSETS_DIR}/plural-trust-manager"
DOWNLOAD_ASSETS_ONLY=false

# K3s configuration
K3S_LOCAL_IMAGES_DIR="/var/lib/rancher/k3s/agent/images"
K3S_MANIFESTS_DIR="/var/lib/rancher/k3s/server/manifests"
K3S_REGISTRY_FILE="/etc/rancher/k3s/registries.yaml"
K3S_VERSION=${K3S_VERSION:-"1.32.0"}

# Bundle images configuration
K3S_BUNDLE_IMAGE="docker.io/floreks/k3s-bundle:${K3S_VERSION}" # TODO: change to pluralsh
PLURAL_BUNDLE_IMAGE="ghcr.io/pluralsh/kairos-plural-bundle:1.0.0"
PLURAL_IMAGES_BUNDLE_IMAGE="ghcr.io/pluralsh/kairos-plural-images-bundle:1.0.0"
PLURAL_TRUST_MANAGER_BUNDLE_IMAGE="ghcr.io/pluralsh/kairos-plural-trust-manager-bundle:0.2.0"

# Plural configuration
PLURAL_CLI_IMAGE="ghcr.io/pluralsh/kairos-plural-cli:0.12.0"

# Command line arguments
TOKEN=""
URL=""

###############################################################################
# Setup and utility functions
###############################################################################
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Bootstrap script for K3s with Plural integration on edge devices.

OPTIONS:
    -t, --token TOKEN       Plural console authentication token (required)
    -u, --url URL          Plural console URL (required)
    -h, --help             Show this help message

ENVIRONMENT VARIABLES:
    K3S_VERSION            K3s version to install (default: 1.32.0)
    BASE_IMAGE             Base image for templating

EXAMPLES:
    $0 --token "your-token" --url "console.onplural.sh"
    $0 -t "your-token" -u "your-console.onplural.sh"

EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            -t|--token)
                TOKEN="$2"
                shift 2
                ;;
            -u|--url)
                URL="$2"
                shift 2
                ;;
            --download-assets)
                DOWNLOAD_ASSETS_ONLY=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Error: Unknown option $1"
                usage
                exit 1
                ;;
        esac
    done

    if [ "$DOWNLOAD_ASSETS_ONLY" = true ]; then
        echo "Downloading assets only. Use --token and --url to bootstrap K3s with Plural."
        return 0
    fi

    # Validate required arguments
    if [ -z "$TOKEN" ]; then
        echo "Error: Token is required. Use -t or --token to specify."
        usage
        exit 1
    fi

    if [ -z "$URL" ]; then
        echo "Error: URL is required. Use -u or --url to specify."
        usage
        exit 1
    fi
}

templ() {
    local file="$3"
    local value="$2"
    local sentinel="$1"
    sed -i "s/@${sentinel}@/$(echo "${value}" | sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//')/g" "${file}"
}

generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    elif [ -r /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
    else
        # Fallback: generate pseudo-random UUID
        od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
    fi
}

check_system_requirements() {
    echo "Checking system requirements for K3s..."

    # Check if running as root or with sudo
    if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        echo "Error: This script requires root privileges or passwordless sudo"
        exit 1
    fi

    # Check cgroups v1 or v2 availability
    if [ ! -d "/sys/fs/cgroup" ]; then
        echo "Error: cgroups not available - /sys/fs/cgroup not found"
        exit 1
    fi

    # Check cgroup version and required controllers
    if [ -f "/sys/fs/cgroup/cgroup.controllers" ]; then
        echo "Found cgroups v2"
        cgroup_version="v2"

        # Check if memory controller is available in cgroups v2
        if ! grep -q "memory" /sys/fs/cgroup/cgroup.controllers 2>/dev/null; then
            echo "Error: memory controller not available in cgroups v2"
            echo "Available controllers: $(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null || echo 'none')"
            exit 1
        fi

        # Check if cpu controller is available in cgroups v2
        if ! grep -q "cpu" /sys/fs/cgroup/cgroup.controllers 2>/dev/null; then
            echo "Error: cpu controller not available in cgroups v2"
            exit 1
        fi

        # Check if pids controller is available in cgroups v2
        if ! grep -q "pids" /sys/fs/cgroup/cgroup.controllers 2>/dev/null; then
            echo "Warning: pids controller not available in cgroups v2"
        fi

    elif [ -d "/sys/fs/cgroup/memory" ] && [ -d "/sys/fs/cgroup/cpu" ]; then
        echo "Found cgroups v1"
        cgroup_version="v1"

        # Check if memory cgroup is properly mounted and accessible
        if [ ! -f "/sys/fs/cgroup/memory/memory.limit_in_bytes" ]; then
            echo "Error: memory cgroup not properly configured in cgroups v1"
            exit 1
        fi

        # Check if cpu cgroup is properly mounted and accessible
        if [ ! -f "/sys/fs/cgroup/cpu/cpu.shares" ]; then
            echo "Error: cpu cgroup not properly configured in cgroups v1"
            exit 1
        fi

    else
        echo "Error: Neither cgroups v1 nor v2 properly configured"
        echo "Available cgroup mounts:"
        mount | grep cgroup || echo "No cgroup mounts found"
        exit 1
    fi

    # Check systemd availability
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "Warning: systemd not found - K3s will run without systemd service"
    fi

    # Check available disk space (minimum 1GB)
    available_space=$(df /var/lib 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [ "${available_space}" -lt 1048576 ]; then  # 1GB in KB
        echo "Warning: Less than 1GB available space in /var/lib"
    fi

    # Check if iptables is available
    if ! command -v iptables >/dev/null 2>&1; then
        echo "Error: iptables not found - required for K3s networking"
        exit 1
    fi

    echo "System requirements check passed (cgroups: ${cgroup_version})"
}

download_assets_from_oci() {
    oci_image="${1}"
    assets_dir="${2}"
    temp_dir=$(mktemp -d)
    container_name="assets-$$"

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

check_local_asset() {
    asset_path="$1"
    if [ -f "${asset_path}" ]; then
        echo "Using local asset: ${asset_path}"
        return 0
    elif [ -d "${asset_path}" ] && [ "$(ls -A "${asset_path}")" ]; then
        echo "Using local dir asset: ${asset_path}"
        return 0
    else
        echo "Local asset not found: ${asset_path}"
        return 1
    fi
}

#############################################################################
# Main functions
#############################################################################

# Downloads all required assets locally.
download_all_assets() {
    echo "Downloading all required assets locally..."
    vendor plural
    vendor k3s
    vendor bundles
    echo "All assets downloaded to ${ASSETS_DIR}"
}

# Vendor assets for K3s and Plural
# Usage: vendor <target>
# Targets:
#   k3s     - Vendor K3s assets
#   plural  - Vendor Plural assets
vendor() {
    target="${1}"

    if [ -z "${target}" ]; then
        echo "Usage: vendor <target>"
        exit 1
    fi

    case "${target}" in
        k3s)
            vendor_k3s
            ;;
        plural)
            vendor_plural
            ;;
        bundles)
            vendor_bundles
            ;;
        *)
            echo "Unknown vendor target: ${target}"
            exit 1
            ;;
    esac
}

# Downloads K3s assets from the specified OCI image if not present locally.
vendor_k3s() {
    assets_missing=false

    if ! check_local_asset "${K3S_ASSETS_DIR}/k3s" >/dev/null 2>&1; then
        assets_missing=true
    fi

    if ! check_local_asset "${K3S_ASSETS_DIR}/k3s-airgap-images.tar.gz" >/dev/null 2>&1; then
        assets_missing=true
    fi

    if ! check_local_asset "${K3S_ASSETS_DIR}/install.sh" >/dev/null 2>&1; then
        assets_missing=true
    fi

    if [ "$assets_missing" = true ]; then
        echo "Some K3s assets are missing, downloading..."
        download_assets_from_oci "${K3S_BUNDLE_IMAGE}" "${K3S_ASSETS_DIR}"
    fi

    echo "K3s assets are ready in ${K3S_ASSETS_DIR}"
}

# Vendors Plural assets, downloading from OCI if not present locally.
vendor_plural() {
    if ! check_local_asset "${PLURAL_ASSETS_DIR}"; then
        echo "Plural bundle assets not found, downloading..."
        download_assets_from_oci "${PLURAL_BUNDLE_IMAGE}" "${PLURAL_ASSETS_DIR}"
    fi

    echo "Plural assets are ready in ${PLURAL_ASSETS_DIR}"
}

# Vendors Plural images and trust manager assets, downloading from OCI if not present locally.
vendor_bundles() {
    if ! check_local_asset "${PLURAL_IMAGES_ASSETS_DIR}"; then
        echo "Plural images bundle assets not found, downloading..."
        download_assets_from_oci "${PLURAL_IMAGES_BUNDLE_IMAGE}" "${PLURAL_IMAGES_ASSETS_DIR}"
        rm "${PLURAL_IMAGES_ASSETS_DIR}"/k3s-airgap-images-*.tar
    fi

    if ! check_local_asset "${PLURAL_TRUST_MANAGER_ASSETS_DIR}"; then
        echo "Plural trust manager bundle assets not found, downloading..."
        download_assets_from_oci "${PLURAL_TRUST_MANAGER_BUNDLE_IMAGE}" "${PLURAL_TRUST_MANAGER_ASSETS_DIR}"
    fi

    echo "Plural bundles assets are ready in ${PLURAL_IMAGES_ASSETS_DIR} and ${PLURAL_TRUST_MANAGER_ASSETS_DIR}"
}

# Installs K3s with the specified version, using assets from the vendor directory.
install_k3s() {
    k3s_version="${1}"

    if [ -z "${k3s_version}" ]; then
        echo "K3s version not specified"
        exit 1
    fi

    echo "Installing K3s version ${k3s_version}..."

    # Install K3s binary
    sudo cp "${K3S_ASSETS_DIR}/k3s" /usr/local/bin/k3s
    sudo chmod +x /usr/local/bin/k3s

    # Setup K3s directories
    sudo mkdir -p "${K3S_LOCAL_IMAGES_DIR}"

    # Handle airgap images
    sudo cp "${K3S_ASSETS_DIR}/k3s-airgap-images.tar.gz" "${K3S_LOCAL_IMAGES_DIR}/"

    # Get install script
    cp "${K3S_ASSETS_DIR}/install.sh" /tmp/install.sh
    chmod +x /tmp/install.sh

    # Install K3s
    export INSTALL_K3S_SKIP_DOWNLOAD=true
    export INSTALL_K3S_EXEC="--node-name=plural --embedded-registry --disable=traefik,servicelb"
    export K3S_KUBECONFIG_MODE="644"

    sudo -E /tmp/install.sh

    # Cleanup
    rm -f /tmp/install.sh

    # Wait for K3s to start with continuous checking
    echo "Waiting for K3s to start..."
    max_attempts=60  # 5 minutes timeout
    attempt=0

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

# Installs Plural by templating assets and copying manifests to K3s directories.
install_plural() {
    echo "Setting up Plural..."

    echo "Generating machine ID..."
    uuid=$(generate_uuid)
    echo "${uuid}" | sudo tee "/etc/plural-id" > /dev/null

    sudo mkdir -p "${K3S_MANIFESTS_DIR}"

    echo "Templating Plural assets..."
    for FILE in "${PLURAL_ASSETS_DIR}"/*; do
      templ "BASE_IMAGE" "${PLURAL_CLI_IMAGE}" "${FILE}"
      templ "TOKEN" "${TOKEN}" "${FILE}"
      templ "URL" "${URL}" "${FILE}"
      templ "MACHINE_ID" "$(cat /etc/plural-id)" "${FILE}"
    done;

    echo "Copying Plural manifests to K3s manifests directory..."
    sudo cp -rfv "${PLURAL_ASSETS_DIR}"/* "${K3S_MANIFESTS_DIR}"

    echo "Plural setup complete!"
}

# Installs additional bundles for Plural, copying images and manifests to K3s directories.
install_bundles() {
  echo "Setting up additional bundles..."

  echo "Copying Plural images to K3s images directory..."
  sudo cp -rfv "${PLURAL_IMAGES_ASSETS_DIR}"/* "${K3S_LOCAL_IMAGES_DIR}"

  echo "Copying trust manager manifests to K3s manifests directory..."
  sudo cp -rfv "${PLURAL_TRUST_MANAGER_ASSETS_DIR}"/* "${K3S_MANIFESTS_DIR}"

  echo "Additional bundles setup complete!"
}

# Sets up the K3s registry configuration file.
setup_registry() {
    echo "Setting up K3s registry configuration..."

    sudo mkdir -p "$(dirname "${K3S_REGISTRY_FILE}")"

    # Create or overwrite the registries.yaml file
    cat << EOF | sudo tee "${K3S_REGISTRY_FILE}" >/dev/null
mirrors:
  "*":
EOF

  echo "Registry configuration for K3s created at ${K3S_REGISTRY_FILE}"
}

###############################################################################
# Main script execution
###############################################################################
main() {
    # Parse command line arguments
    parse_args "$@"

    if [ "$DOWNLOAD_ASSETS_ONLY" = true ]; then
        download_all_assets
        exit 0
    fi

    echo "Starting Plural bootstrap with:"
    echo "  Token: $(echo "$TOKEN" | cut -c1-5)..."
    echo "  URL: ${URL}"

    # Check system requirements first
    check_system_requirements

    # Vendor assets if needed
    vendor plural
    vendor bundles
    vendor k3s

    # Install K3s
    install_plural
    install_bundles
    setup_registry
    install_k3s "${K3S_VERSION}"

    # Clean up assets directory
    rm -rf "${ASSETS_DIR}"

    echo "Bootstrap completed successfully!"
}

# Run the main function with all arguments
main "$@"