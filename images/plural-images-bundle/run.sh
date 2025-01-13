#!/bin/bash

K3S_IMAGES_DIR=${K3S_IMAGES_DIR:-/usr/local/.state/var-lib-rancher.bind/k3s/agent/images/}

mkdir -p "${K3S_IMAGES_DIR}"

cp -rfv assets/* "${K3S_IMAGES_DIR}"

