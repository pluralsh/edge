#!/bin/bash

set -ex

K3S_MANIFEST_DIR=${K3S_MANIFEST_DIR:-/var/lib/rancher/k3s/server/manifests/}

# DEFAULTS
# renovate: datasource=docker depName=ghcr.io/pluralsh/plural-cli-cloud
BASE_IMAGE="ghcr.io/pluralsh/plural-cli-cloud:0.11.1"
TOKEN=""
URL=""
CLUSTER_NAME="plural-edge"
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
    sed -i "s/@${sentinel}@/$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"${value}")/g" "${file}"
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

    _clusterName=$(getConfig plural.clusterName)
    if [ "$_clusterName" != "" ]; then
        CLUSTER_NAME=$_clusterName
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
  templ "CLUSTER_NAME" "${CLUSTER_NAME}" "${FILE}"
  templ "PROJECT" "${PROJECT}" "${FILE}"
  templ "TAG" "${TAG}" "${FILE}"
done;

cp -rf assets/* "${K3S_MANIFEST_DIR}"