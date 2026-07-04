# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

# Image configuration
IMAGE_NAME ?= stableos
IMAGE_TAG ?= latest
CONTAINERFILE ?= ./Containerfile
PLATFORM ?= linux/amd64

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
		--platform $(PLATFORM) \
		-f $(CONTAINERFILE) \
		-t $(IMAGE_NAME):$(IMAGE_TAG)

output/bootiso/stableos.iso: build podman ## Build bootable ISO for installation
	mkdir -p output/bootiso
	$(PODMAN) run --rm --privileged \
		--platform $(PLATFORM) \
		--security-opt label=type:unconfined_t \
		--volume /var/lib/containers/storage:/var/lib/containers/storage \
		--volume ./output:/output \
		--volume ./config.toml:/config.toml:ro \
		quay.io/centos-bootc/bootc-image-builder:latest \
		build \
		--target-arch $(subst linux/,,$(PLATFORM)) \
		--type iso \
		--rootfs btrfs \
		--local $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: iso
iso: output/bootiso/stableos.iso ## Build bootable ISO for installation

##@ Linting and Formatting

.PHONY: pre-commit-install
pre-commit-install: uv ## Install pre-commit hooks
	@$(UVX) pre-commit install > /dev/null

.PHONY: fmt
fmt: pre-commit-install hadolint fish ## Run pre-commit hooks against all files
	$(UVX) pre-commit run --all-files

.PHONY: lint-fish
lint-fish: fish ## Check fish config syntax
	@if [ "$(OS)" = "darwin" ]; then \
		fish --no-execute files/skel/.config/fish/config.fish; \
	else \
		$(FISH_BIN) --no-execute files/skel/.config/fish/config.fish; \
	fi

##@ Testing

.PHONY: test
test: test-container-structure ## Run all tests

.PHONY: test-container-structure
test-container-structure: container-structure-test ## Run container structure tests
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
FISH_BIN ?= $(LOCALBIN)/fish-$(FISH_VERSION)
UV_DIR ?= $(LOCALBIN)/uv-$(UV_VERSION)
UV ?= $(UV_DIR)/uv
UVX ?= $(UV_DIR)/uvx

## Tool Versions
CONTAINER_STRUCTURE_TEST_VERSION ?= v1.22.1
HADOLINT_VERSION ?= v2.14.0
PODMAN_VERSION ?= v6.0.0
FISH_VERSION ?= 4.8.0
UV_VERSION ?= 0.11.26

.PHONY: fish
fish: $(FISH_BIN) ## Download fish binary locally if necessary (non-macOS only)

# TODO(nateinaction): Use directly downloaded fish binary on MacOS when builds are available in Github
# which is suppoesed to be soon according to the fish-shell release page:
# https://github.com/fish-shell/fish-shell/releases/tag/4.8.0
$(FISH_BIN): $(LOCALBIN)
	@FISH_ARCH=`[ "$(ARCH)" = "amd64" ] && echo x86_64 || ([ "$(ARCH)" = "arm64" ] && echo aarch64 || echo $(ARCH))`; \
		curl -o /tmp/fish-$(FISH_VERSION).tar.xz -sL https://github.com/fish-shell/fish-shell/releases/download/$(FISH_VERSION)/fish-$(FISH_VERSION)-linux-$$FISH_ARCH.tar.xz && \
		tar -xJf /tmp/fish-$(FISH_VERSION).tar.xz -C /tmp && \
		mv /tmp/fish $(FISH_BIN) && \
		rm /tmp/fish-$(FISH_VERSION).tar.xz && \
		chmod +x $(FISH_BIN) && \
		touch $(FISH_BIN)

.PHONY: hadolint
hadolint: $(HADOLINT) ## Download hadolint locally if necessary

$(HADOLINT): $(LOCALBIN)
	@HADOLINT_OS=`[ "$(OS)" = "darwin" ] && echo macos || echo linux`; \
		HADOLINT_ARCH=`[ "$(ARCH)" = "amd64" ] && echo x86_64 || echo $(ARCH)`; \
		curl -o $(HADOLINT) -L https://github.com/hadolint/hadolint/releases/download/$(HADOLINT_VERSION)/hadolint-$$HADOLINT_OS-$$HADOLINT_ARCH; \
		chmod +x $(HADOLINT)

.PHONY: container-structure-test
container-structure-test: $(CONTAINER_STRUCTURE_TEST) ## Download container-structure-test locally if necessary

$(CONTAINER_STRUCTURE_TEST): $(LOCALBIN)
	@curl -o $(CONTAINER_STRUCTURE_TEST) -sL https://github.com/GoogleContainerTools/container-structure-test/releases/download/$(CONTAINER_STRUCTURE_TEST_VERSION)/container-structure-test-$(OS)-$(ARCH) && \
		chmod +x $(CONTAINER_STRUCTURE_TEST) && \
		touch $(CONTAINER_STRUCTURE_TEST)

.PHONY: podman
podman: $(PODMAN) ## Download podman locally if necessary

$(PODMAN): $(LOCALBIN)
	@curl -o /tmp/podman.zip -sL https://github.com/podman-container-tools/podman/releases/download/$(PODMAN_VERSION)/podman-remote-release-$(OS)_$(ARCH).zip && \
		unzip -oq /tmp/podman.zip -d "$$(dirname $(PODMAN))" && \
		find "$$(dirname $(PODMAN))" -name podman -type f -exec mv {} $(PODMAN) \; && \
		find "$$(dirname $(PODMAN))" -maxdepth 1 -type d -name 'podman-*' -exec rm -rf {} + && \
		chmod +x $(PODMAN) && \
		touch $(PODMAN) && \
		rm /tmp/podman.zip

.PHONY: uv
uv: $(UV) ## Download uv locally if necessary

$(UV): $(LOCALBIN)
	@mkdir -p $(UV_DIR) && \
		curl -LsSf https://astral.sh/uv/$(UV_VERSION)/install.sh | UV_UNMANAGED_INSTALL=$(UV_DIR) sh > /dev/null && \
		touch $(UV)
