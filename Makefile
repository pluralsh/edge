PWD := $(shell pwd)
UNAME := $(shell uname)

IMAGE := quay.io/kairos/alpine:3.19-standard-arm64-rpi4-v3.2.4-k3sv1.31.3-k3s1

# Replace it with your device name of memory card
DEVICE_PATH := /dev/rdisk4

TARGETARCH ?= arm64

ifeq ($(UNAME), Linux)
	BS := 10MB
endif
ifeq ($(UNAME), Darwin)
	BS := 10m
endif

##@ Build

.PHONY: build
build: build-bundle build-cli ## build all images

.PHONY: buile-bundle
build-bundle: ## build bundle image
	docker build -f bundle.Dockerfile --build-arg TARGETARCH=$(TARGETARCH) .

.PHONY: build-cli
build-cli: ## build CLI image
	docker build -f cli.Dockerfile --build-arg TARGETARCH=$(TARGETARCH) .

.PHONY: create-iso
create-iso: ## create ISO file with cloud config
	mkdir -p build
	docker pull ${IMAGE}
	docker run \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "${PWD}"/build:/tmp \
		-v "${PWD}"/cloud-config.yaml:/cloud-config.yaml \
		--privileged -ti --rm \
		--entrypoint=/build-arm-image.sh quay.io/kairos/auroraboot:v0.4.3 \
		--model rpi4 \
		--config /cloud-config.yaml \
		--docker-image ${IMAGE} /tmp/kairos.img

##@ General

.PHONY: help
help: ## show help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

flash-official-image:
ifneq ($(shell id -u), 0)
	@echo "You must be root to perform this action"
else
	docker run -ti --rm -v ${PWD}:/image quay.io/luet/base util unpack ${OFFICIAL_IMAGE}-img /image
	xzcat build/${OFFICIAL_IMAGE}.img.xz | \
	sudo dd of=${DEVICE_PATH} oflag=sync status=progress bs=${BS}
endif


