# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

# Image configuration
IMAGE_NAME ?= stableos
IMAGE_TAG ?= latest
CONTAINERFILE ?= ./Containerfile
PLATFORM ?= linux/amd64

# Dev/lint/test tools (hadolint, container-structure-test, fish, pre-commit)
# come from the flake.nix dev shell -- run inside `nix develop` / direnv so they
# are on PATH. podman ships in the Fedora Atomic base OS and is preinstalled on
# CI runners; override PODMAN to point elsewhere if needed.
PODMAN ?= podman

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

.PHONY: build
build: ## Build container image with podman
	$(PODMAN) build \
		--platform $(PLATFORM) \
		-f $(CONTAINERFILE) \
		-t $(IMAGE_NAME):$(IMAGE_TAG)

output/bootiso/stableos.iso: build ## Build bootable ISO for installation
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
pre-commit-install: ## Install pre-commit hooks
	@pre-commit install > /dev/null

.PHONY: fmt
fmt: pre-commit-install ## Run pre-commit hooks against all files
	pre-commit run --all-files

.PHONY: lint-fish
lint-fish: ## Check fish config syntax
	fish --no-execute files/skel/.config/fish/config.fish

##@ Testing

.PHONY: test
test: test-container-structure ## Run all tests

.PHONY: test-container-structure
test-container-structure: ## Run container structure tests
	container-structure-test test --image $(IMAGE_NAME):$(IMAGE_TAG) --config container-structure-test.yaml

##@ Cleanup

.PHONY: clean
clean: ## Remove built container image
	$(PODMAN) rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
	$(PODMAN) rmi localhost/$(IMAGE_NAME):$(IMAGE_TAG) || true

.PHONY: clean-all
clean-all: clean ## Remove all stableos images
	$(PODMAN) rmi $$($(PODMAN) images -q $(IMAGE_NAME)) || true
