#!/bin/bash

set -e

function cleanup {
  echo "Removing volume"
  docker volume rm edge-rootfs
  rm defaults.yaml
}

trap cleanup EXIT

IMAGE=quay.io/kairos/alpine:3.19-standard-arm64-rpi4-v3.2.4-k3sv1.31.3-k3s1
CLOUD_CONFIG=cloud-config.yaml
SKIP_TEMPLATING=n
FLASH_STORAGE_DEVICE=n

case "$(uname)" in
  Linux) BS=10MB ;;
  Darwin) BS=10m ;;
esac

templ() {
    local file="$3"
    local value="$2"
    local sentinel="$1"
    sed -i "s/@${sentinel}@/$(echo "${value}" | sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//')/g" "${file}"
}

if [ -f $CLOUD_CONFIG ]; then
  read -p "${CLOUD_CONFIG} already exists. Would you like to skip templating and use it? (y/n) " -r SKIP_TEMPLATING
fi
if [ "$SKIP_TEMPLATING" == "${SKIP_TEMPLATING#[Yy]}" ] ;then
  read -p "Enter your Plural Console URL: " -r URL
  read -p "Enter your Plural Console token: " -rs TOKEN
  echo -e ""
  read -p "Enter name for initial user account: " -r USERNAME
  read -p "Enter password for initial user account: " -rs PASSWORD
  echo -e ""
  read -p "Enter name for initial WIFI SSID: " -r WIFISSID
  read -p "Enter password for initial WIFI password: " -rs WIFIPASSWORD
  echo -e ""
  echo "Preparing ${CLOUD_CONFIG}..."
  curl --silent https://raw.githubusercontent.com/pluralsh/edge/main/cloud-config.yaml -o "${CLOUD_CONFIG}"
  templ "URL" "${URL}" "${CLOUD_CONFIG}"
  templ "TOKEN" "${TOKEN}" "${CLOUD_CONFIG}"
  templ "USERNAME" "${USERNAME}" "${CLOUD_CONFIG}"
  templ "PASSWORD" "${PASSWORD}" "${CLOUD_CONFIG}"
  templ "WIFISSID" "${WIFISSID}" "${CLOUD_CONFIG}"
  templ "WIFIPASSWORD" "${WIFIPASSWORD}" "${CLOUD_CONFIG}"
fi

docker volume create edge-rootfs
echo "export image kairos-plural-bundle ..."
docker run -ti --rm --user root \
  --mount source=edge-rootfs,target=/rootfs \
  gcr.io/go-containerregistry/crane:latest \
  --platform=linux/arm64 pull ghcr.io/pluralsh/kairos-plural-bundle:0.1.4 /rootfs/plural-bundle.tar
echo "export image kairos-plural-images-bundle ..."
docker run -ti --rm --user root \
  --mount source=edge-rootfs,target=/rootfs \
  gcr.io/go-containerregistry/crane:latest \
  --platform=linux/arm64 pull ghcr.io/pluralsh/kairos-plural-images-bundle:0.1.2 /rootfs/plural-images-bundle.tar
echo "export image kairos-plural-trust-manager-bundle ..."
docker run -ti --rm --user root \
  --mount source=edge-rootfs,target=/rootfs \
  gcr.io/go-containerregistry/crane:latest \
  --platform=linux/arm64 pull ghcr.io/pluralsh/kairos-plural-trust-manager-bundle:0.1.0 /rootfs/plural-trust-manager-bundle.tar
echo "unpack image $IMAGE ..."
docker run -ti --rm --privileged\
  --mount source=edge-rootfs,target=/rootfs \
  quay.io/luet/base \
  util unpack ${IMAGE} /rootfs


echo '#cloud-config' >> defaults.yaml

echo "Building image..."
mkdir -p build
docker run \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD"/build:/tmp/build \
  -v "$PWD"/"$CLOUD_CONFIG":/cloud-config.yaml \
  -v "$PWD"/defaults.yaml:/defaults.yaml \
  --mount source=edge-rootfs,target=/rootfs \
  --privileged -ti --rm \
  --entrypoint=/build-arm-image.sh quay.io/kairos/auroraboot:v0.4.3 \
  --model rpi4 \
  --directory /rootfs \
  --config /cloud-config.yaml /tmp/build/kairos.img
echo "Successfully built image and saved it to the build directory!"

read -p "Would you like to flash storage device now? (y/n) " -r FLASH_STORAGE_DEVICE
if [ "$FLASH_STORAGE_DEVICE" != "${FLASH_STORAGE_DEVICE#[Yy]}" ] ;then
  read -p "Enter path of storage device, i.e. /dev/rdisk4: " -r STORAGE_DEVICE_PATH
  echo "Flashing storage device..."
  sudo dd if=build/kairos.img of="${STORAGE_DEVICE_PATH}" oflag=sync status=progress bs=$BS
  echo "Successfully flashed storage device, now you can connect it to your Raspberry Pi 4!"
fi
