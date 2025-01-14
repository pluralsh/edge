#!/bin/bash

set -e

if [ -z "${IMAGE}" ]; then
  echo "IMAGE environment variable not set"
  exit 1
fi

echo "Exporting $IMAGE contents..."
mkdir -p image
luet util unpack "$IMAGE" /image

BUNDLES_DIRECTORY=/image/usr/local/bundles
echo "Preparing $BUNDLES_DIRECTORY..."
mkdir -p $BUNDLES_DIRECTORY

PLURAL_BUNDLE="ghcr.io/pluralsh/kairos-plural-bundle:0.1.4"
echo "Adding $PLURAL_BUNDLE bundle..."
docker pull $PLURAL_BUNDLE
docker save $PLURAL_BUNDLE -o $BUNDLES_DIRECTORY/plural-bundle.tar

PLURAL_IMAGES_BUNDLE="ghcr.io/pluralsh/kairos-plural-images-bundle:0.1.1"
echo "Adding $PLURAL_IMAGES_BUNDLE bundle..."
docker pull $PLURAL_IMAGES_BUNDLE
docker save $PLURAL_IMAGES_BUNDLE -o $BUNDLES_DIRECTORY/plural-images-bundle.tar

echo "Building image..."
/build-arm-image.sh  --model rpi4 --directory /image --config /cloud-config.yaml /tmp/build/kairos.img
