TARGETARCH ?= arm64

##@ Build

.PHONY: build
build: build-bundle build-cli ## build all images

.PHONY: buile-bundle
build-bundle: ## build bundle image
	docker build -f bundle.Dockerfile --build-arg TARGETARCH=$(TARGETARCH) .

.PHONY: build-cli
build-cli: ## build CLI image
	docker build -f cli.Dockerfile --build-arg TARGETARCH=$(TARGETARCH) .

##@ General

.PHONY: help
help: ## show help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
