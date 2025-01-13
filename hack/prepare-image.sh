#!/bin/bash

set -e

if [ -z "${IMAGE}" ]; then
  echo "IMAGE environment variable not set"
  exit 1
fi

echo "Exporting $IMAGE contents..."
mkdir -p image
docker create "$IMAGE" | xargs docker export > image.tar
tar -xf image.tar -C image

PLURAL_BUNDLE="ghcr.io/pluralsh/kairos-plural-bundle:0.1.4"
echo "Adding $PLURAL_BUNDLE bundle..."
mkdir -p image/run/initramfs/live/
docker pull $PLURAL_BUNDLE
docker save $PLURAL_BUNDLE -o image/run/initramfs/live/plural-bundle.tar

PLURAL_IMAGES_BUNDLE="ghcr.io/pluralsh/kairos-plural-images-bundle:0.1.0"
echo "Adding $PLURAL_IMAGES_BUNDLE bundle..."
mkdir -p image/run/initramfs/live/
docker pull $PLURAL_IMAGES_BUNDLE
docker save $PLURAL_IMAGES_BUNDLE -o image/run/initramfs/live/plural-images-bundle.tar
