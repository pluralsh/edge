PWD := $(shell pwd)
UNAME := $(shell uname)

# We have experienced some issues with the latest image, that’s why it’s previous version
OFFICIAL_IMAGE := quay.io/kairos/alpine:3.19-standard-arm64-rpi3-v3.2.3-k3sv1.31.2-k3s1-img

# Replace it with your device name of memory card
DEVICE_PATH := /dev/rdisk4

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
