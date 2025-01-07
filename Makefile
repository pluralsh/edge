PWD := $(shell pwd)
UNAME := $(shell uname)

IMAGE := quay.io/kairos/alpine:3.19-standard-arm64-rpi4-v3.2.4-k3sv1.31.3-k3s1
OFFICIAL_IMAGE := ${IMAGE}-img

CUSTOM_IMAGE := ghcr.io/pluralsh/edge:latest

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
	xzcat build/${IMAGE}.img.xz | \
	sudo dd of=${DEVICE_PATH} oflag=sync status=progress bs=${BS}
endif

build-custom-image:
	docker build --build-arg TARGETARCH=$(TARGETARCH) .

create-custom-iso:
	rm -r build
	mkdir -p build
	docker run -v ${PWD}:/HERE \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--privileged -i --rm \
		--entrypoint=/build-arm-image.sh quay.io/kairos/auroraboot:v0.4.3 \
		--model rpi4 \
		--state-partition-size 6200 \
		--recovery-partition-size 4200 \
		--size 15200 \
		--images-size 2000 \
		--config /HERE/cloud-config.yaml \
 		--docker-image ${CUSTOM_IMAGE} /HERE/build/out.img
