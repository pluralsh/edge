PWD := $(shell pwd)
UNAME := $(shell uname)

# We have experienced some issues with the latest image, that’s why it’s previous version
OFFICIAL_IMAGE := quay.io/kairos/alpine:3.19-standard-arm64-rpi3-v3.2.3-k3sv1.31.2-k3s1-img

# TODO: Add latest tag and use it here
CUSTOM_IMAGE := ghcr.io/pluralsh/edge:sha-456f53e

# Replace it with your device name of memory card
DEVICE_PATH := /dev/rdisk4

TARGETARCH ?= arm64

ifeq ($(UNAME), Linux)
	BS := 10MB
endif
ifeq ($(UNAME), Darwin)
	BS := 10m
endif

flash-official-image:
ifneq ($(shell id -u), 0)
	@echo "You must be root to perform this action"
else
	docker run -ti --rm -v ${PWD}:/image quay.io/luet/base util unpack ${OFFICIAL_IMAGE} /image
	xzcat build/kairos-alpine-3.19-standard-arm64-rpi3-v3.2.3-k3sv1.31.2+k3s1.img.xz | \
	sudo dd of=${DEVICE_PATH} oflag=sync status=progress bs=${BS}
endif

build-custom-image:
	docker build --build-arg TARGETARCH=$(TARGETARCH) .

# TODO: Verify/fix
create-custom-iso:
	mkdir -p build
	docker run -v ${PWD}:/HERE \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--privileged -i --rm \
		--entrypoint=/build-arm-image.sh quay.io/kairos/auroraboot:v0.4.3 \
		--model rpi3 \
		--state-partition-size 6200 \
		--recovery-partition-size 4200 \
		--size 15200 \
		--images-size 2000 \
		--config /HERE/cloud-config.yaml \
 		--docker-image ${CUSTOM_IMAGE} /HERE/build/out.img
