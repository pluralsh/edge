#!/bin/bash

set -ex

K3S_MANIFEST_DIR=${K3S_MANIFEST_DIR:-/var/lib/rancher/k3s/server/manifests/}

CERT_MANAGER_VERSION="v1.16.2"

VERSION="v0.15.0"

getConfig() {
    local l=$1
    key=$(kairos-agent config get "${l}" | tr -d '\n')
    if [ "$key" != "null" ]; then
     echo "${key}"
    fi
    echo
}

templ() {
    local file="$3"
    local value="$2"
    local sentinel="$1"
    sed -i "s/@${sentinel}@/${value}/g" "${file}"
}

readConfig() {
    _certManagerVersion=$(getConfig plural.certManagerVersion)
    if [ "$_certManagerVersion" != "" ]; then
        CERT_MANAGER_VERSION=$_certManagerVersion
    fi

    _version=$(getConfig plural.trustManagerVersion)
    if [ "$_version" != "" ]; then
        VERSION=$_version
    fi
}

mkdir -p "${K3S_MANIFEST_DIR}"

readConfig

# Copy manifests, and template them
for FILE in assets/*; do
  templ "CERT_MANAGER_VERSION" "${CERT_MANAGER_VERSION}" "${FILE}"
  templ "VERSION" "${VERSION}" "${FILE}"
done;

cp -rfv assets/* "${K3S_MANIFEST_DIR}"