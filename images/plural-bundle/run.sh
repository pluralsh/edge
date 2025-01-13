#!/bin/sh

set -ex

K3S_MANIFEST_DIR=${K3S_MANIFEST_DIR:-/var/lib/rancher/k3s/server/manifests/}

# DEFAULTS
# renovate: datasource=docker depName=ghcr.io/pluralsh/plural-cli-cloud
BASE_IMAGE="ghcr.io/pluralsh/kairos-plural-cli:0.11.1"
TOKEN=""
URL=""
CLUSTER_NAME_PREFIX="plural-edge"
PROJECT="default"
TAG="plural=edge"

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

    _clusterNamePrefix=$(getConfig plural.clusterNamePrefix)
    if [ "$_clusterNamePrefix" != "" ]; then
        CLUSTER_NAME_PREFIX=$_clusterNamePrefix
    fi

    _project=$(getConfig plural.project)
    if [ "$_project" != "" ]; then
        PROJECT=$_project
    fi

    _tag=$(getConfig plural.tag)
    if [ "$_tag" != "" ]; then
        TAG=$_tag
    fi
}

mkdir -p "${K3S_MANIFEST_DIR}"

readConfig

# Copy manifests, and template them
for FILE in assets/*; do
  templ "BASE_IMAGE" "${BASE_IMAGE}" "${FILE}"
  templ "TOKEN" "${TOKEN}" "${FILE}"
  templ "URL" "${URL}" "${FILE}"
  templ "CLUSTER_NAME" "${CLUSTER_NAME_PREFIX}-$(cut -c1-10 < /etc/machine-id)" "${FILE}"
  templ "PROJECT" "${PROJECT}" "${FILE}"
  templ "TAG" "${TAG}" "${FILE}"
done;

cp -rfv assets/* "${K3S_MANIFEST_DIR}"