#!/bin/sh

set -ex

K3S_MANIFEST_DIR=${K3S_MANIFEST_DIR:-/var/lib/rancher/k3s/server/manifests/}

# TODO: Write renovate config to keep it up to date.
BASE_IMAGE="ghcr.io/pluralsh/kairos-plural-cli:0.12.0"
TOKEN=""
URL=""

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
    sed -i "s/@${sentinel}@/$(echo "${value}" | sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//')/g" "${file}"
}

readConfig() {
    _baseImage=$(getConfig plural.baseImage)
    if [ "$_baseImage" != "" ]; then
        BASE_IMAGE=$_baseImage
    fi

    _token=$(getConfig plural.token)
    if [ "$_token" != "" ]; then
        TOKEN=$_token
    fi

    _url=$(getConfig plural.url)
    if [ "$_url" != "" ]; then
        URL=$_url
    fi
}

mkdir -p "${K3S_MANIFEST_DIR}"

readConfig

# Copy manifests, and template them
for FILE in assets/*; do
  templ "BASE_IMAGE" "${BASE_IMAGE}" "${FILE}"
  templ "TOKEN" "${TOKEN}" "${FILE}"
  templ "URL" "${URL}" "${FILE}"
  templ "MACHINE_ID" "$(cat /etc/plural-id)" "${FILE}"
done;

cp -rfv assets/* "${K3S_MANIFEST_DIR}"