# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

# Image configuration
IMAGE_NAME ?= stableos
IMAGE_TAG ?= latest
CONTAINERFILE ?= ./Containerfile

# Target architecture for the built image and ISO. The ISO must be amd64 so it
# boots on standard x86_64 hardware, even when building from an arm64 host.
TARGET_ARCH ?= amd64

##@ General

.PHONY: all
all: fmt build test ## Run lint, build, and test

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

PODMAN_RUNNER ?= go run github.com/containers/podman/v6/cmd/podman@$(PODMAN_VERSION)

.PHONY: build
build: podman ## Build container image with podman
	$(PODMAN) build \
		--platform linux/$(TARGET_ARCH) \
		-f $(CONTAINERFILE) \
		-t $(IMAGE_NAME):$(IMAGE_TAG)

output/bootiso/stableos.iso: build podman ## Build bootable ISO for installation
	mkdir -p output/bootiso
	$(PODMAN) run --rm --privileged \
		--platform linux/$(TARGET_ARCH) \
		--security-opt label=type:unconfined_t \
		-v ./output:/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso --target-arch $(TARGET_ARCH) --local $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: iso
iso: output/bootiso/stableos.iso ## Build bootable ISO for installation

##@ Linting and Formatting

.PHONY: pre-commit-install
pre-commit-install: uv hadolint ## Install pre-commit hooks
	@$(UVX) pre-commit install > /dev/null

.PHONY: fmt
fmt: pre-commit-install ## Run pre-commit hooks against all files
	$(UVX) pre-commit run --all-files

##@ Testing

.PHONY: test
test: test-container-structure ## Run all tests

.PHONY: test-container-structure
test-container-structure: build container-structure-test ## Run container structure tests
	$(CONTAINER_STRUCTURE_TEST) test --image $(IMAGE_NAME):$(IMAGE_TAG) --config container-structure-test.yaml

##@ Cleanup

.PHONY: clean
clean: podman ## Remove built container image
	$(PODMAN) rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
	$(PODMAN) rmi localhost/$(IMAGE_NAME):$(IMAGE_TAG) || true

.PHONY: clean-all
clean-all: clean ## Remove all stableos images
	$(PODMAN) rmi $$($(PODMAN) images -q $(IMAGE_NAME)) || true

##@ Build Dependencies

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/build
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## System Environment
ARCH := $(shell uname -m | sed 's/x86_64/amd64/')
OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')

## Tool Binaries
HADOLINT ?= $(LOCALBIN)/hadolint-$(HADOLINT_VERSION)
CONTAINER_STRUCTURE_TEST ?= $(LOCALBIN)/container-structure-test-$(CONTAINER_STRUCTURE_TEST_VERSION)
PODMAN ?= $(LOCALBIN)/podman-$(PODMAN_VERSION)
UV_DIR ?= $(LOCALBIN)/uv-$(UV_VERSION)
UV ?= $(UV_DIR)/uv
UVX ?= $(UV_DIR)/uvx

## Tool Versions
CONTAINER_STRUCTURE_TEST_VERSION ?= v1.22.1
HADOLINT_VERSION ?= v2.14.0
PODMAN_VERSION ?= v6.0.0
UV_VERSION ?= 0.11.26

.PHONY: hadolint
hadolint: $(HADOLINT) ## Download hadolint locally if necessary

$(HADOLINT): $(LOCALBIN)
	HADOLINT_OS=`[ "$(OS)" = "darwin" ] && echo macos || echo linux`; \
	curl -o $(HADOLINT) -L https://github.com/hadolint/hadolint/releases/download/$(HADOLINT_VERSION)/hadolint-$$HADOLINT_OS-$(ARCH); \
	chmod +x $(HADOLINT)

.PHONY: container-structure-test
container-structure-test: $(CONTAINER_STRUCTURE_TEST) ## Download container-structure-test locally if necessary

$(CONTAINER_STRUCTURE_TEST): $(LOCALBIN)
	curl -o $(CONTAINER_STRUCTURE_TEST) -sL https://github.com/GoogleContainerTools/container-structure-test/releases/download/$(CONTAINER_STRUCTURE_TEST_VERSION)/container-structure-test-$(OS)-$(ARCH) && \
		chmod +x $(CONTAINER_STRUCTURE_TEST) && \
		touch $(CONTAINER_STRUCTURE_TEST)

.PHONY: podman
podman: $(PODMAN) ## Download podman locally if necessary

$(PODMAN): $(LOCALBIN)
	curl -o /tmp/podman.zip -sL https://github.com/podman-container-tools/podman/releases/download/$(PODMAN_VERSION)/podman-remote-release-$(OS)_$(ARCH).zip && \
		unzip -oq /tmp/podman.zip -d "$$(dirname $(PODMAN))" && \
		find "$$(dirname $(PODMAN))" -name podman -type f -exec mv {} $(PODMAN) \; && \
		find "$$(dirname $(PODMAN))" -maxdepth 1 -type d -name 'podman-*' -exec rm -rf {} + && \
		chmod +x $(PODMAN) && \
		touch $(PODMAN) && \
		rm /tmp/podman.zip

.PHONY: uv
uv: $(UV) ## Download uv locally if necessary

$(UV): $(LOCALBIN)
	@test -s $(UV) || { mkdir -p $(UV_DIR); curl -LsSf https://astral.sh/uv/$(UV_VERSION)/install.sh | UV_UNMANAGED_INSTALL=$(UV_DIR) sh > /dev/null; }
