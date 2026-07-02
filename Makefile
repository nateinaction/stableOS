# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

# Image configuration
IMAGE_NAME ?= stableos
IMAGE_TAG ?= latest
CONTAINERFILE ?= ./Containerfile

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
build: podman ## Build container image with podman
	$(PODMAN) build \
		-f $(CONTAINERFILE) \
		-t $(IMAGE_NAME):$(IMAGE_TAG)

##@ Linting and Formatting

.PHONY: pre-commit-install
pre-commit-install: uv ## Install pre-commit hooks
	@$(UVX) pre-commit install > /dev/null

.PHONY: fmt
fmt: pre-commit-install ## Run pre-commit hooks against all files
	$(UVX) pre-commit run --all-files

.PHONY: lint-containerfile
lint-containerfile: hadolint ## Lint Containerfile with hadolint
	$(HADOLINT) $(CONTAINERFILE) --ignore DL3041 --failure-threshold warning

.PHONY: lint-workflows
lint-workflows: actionlint ## Lint GitHub Actions workflows
	$(ACTIONLINT)

.PHONY: lint-fish
lint-fish: ## Check fish config syntax
	fish --no-execute files/skel/.config/fish/config.fish

.PHONY: lint-toml
lint-toml: uv ## Parse config.toml
	$(UVX) tomli-w --help >/dev/null 2>&1 || $(UVX) pip install tomli-w
	$(UVX) python3 -c "import tomllib; tomllib.loads(open('config.toml').read())"

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
ACTIONLINT ?= $(LOCALBIN)/actionlint-$(ACTIONLINT_VERSION)
CONTAINER_STRUCTURE_TEST ?= $(LOCALBIN)/container-structure-test-$(CONTAINER_STRUCTURE_TEST_VERSION)
PODMAN ?= $(LOCALBIN)/podman-$(PODMAN_VERSION)/podman
UV_DIR ?= $(LOCALBIN)/uv-$(UV_VERSION)
UV ?= $(UV_DIR)/uv
UVX ?= $(UV_DIR)/uvx

## Tool Versions
HADOLINT_VERSION ?= latest
ACTIONLINT_VERSION ?= latest
CONTAINER_STRUCTURE_TEST_VERSION ?= latest
PODMAN_VERSION ?= latest
UV_VERSION ?= 0.11.26

.PHONY: hadolint
hadolint: $(HADOLINT) ## Download hadolint locally if necessary

$(HADOLINT): $(LOCALBIN)
	@test -s $(HADOLINT) || { \
		if [ "$(OS)" = "darwin" ]; then \
			HADOLINT_ARCH="x86_64"; \
			if [ "$(ARCH)" = "arm64" ]; then HADOLINT_ARCH="arm64"; fi; \
			curl -o $(HADOLINT) -L https://github.com/hadolint/hadolint/releases/latest/download/hadolint-macos-$$HADOLINT_ARCH; \
		else \
			curl -o $(HADOLINT) -L https://github.com/hadolint/hadolint/releases/latest/download/hadolint-linux-$(ARCH); \
		fi && chmod +x $(HADOLINT); \
	}

.PHONY: actionlint
actionlint: $(ACTIONLINT) ## Download actionlint locally if necessary

$(ACTIONLINT): $(LOCALBIN)
	@test -s $(ACTIONLINT) || { \
		VERSION=$$(curl -s https://api.github.com/repos/rhysd/actionlint/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p' | head -1); \
		if [ "$(ARCH)" = "x86_64" ]; then DL_ARCH="amd64"; else DL_ARCH="$(ARCH)"; fi; \
		curl -o /tmp/actionlint.tar.gz -L https://github.com/rhysd/actionlint/releases/latest/download/actionlint_$$VERSION\_$(OS)\_$$DL_ARCH.tar.gz && \
		tar -xzf /tmp/actionlint.tar.gz -C $(LOCALBIN) actionlint && \
		mv $(LOCALBIN)/actionlint $(ACTIONLINT) && \
		chmod +x $(ACTIONLINT) && \
		rm /tmp/actionlint.tar.gz; \
	}

.PHONY: container-structure-test
container-structure-test: $(CONTAINER_STRUCTURE_TEST) ## Download container-structure-test locally if necessary

$(CONTAINER_STRUCTURE_TEST): $(LOCALBIN)
	@test -s $(CONTAINER_STRUCTURE_TEST) || { \
		curl -o $(CONTAINER_STRUCTURE_TEST) -L https://github.com/GoogleContainerTools/container-structure-test/releases/latest/download/container-structure-test-$(OS)-$(ARCH) && \
		chmod +x $(CONTAINER_STRUCTURE_TEST); \
	}

.PHONY: podman
podman: $(PODMAN) ## Download podman locally if necessary

$(PODMAN): $(LOCALBIN)
	@test -s $(PODMAN) || { \
		mkdir -p "$$(dirname $(PODMAN))"; \
		if [ "$(OS)" = "darwin" ]; then \
			PODMAN_ARCH=$$([ "$(ARCH)" = "arm64" ] && echo "arm64" || echo "amd64"); \
			RELEASE_URL=$$(curl -sL https://api.github.com/repos/podman-container-tools/podman/releases/latest | grep -o "https[^\"]*podman-remote-release-darwin_$$PODMAN_ARCH.zip" | head -1); \
			if [ -z "$$RELEASE_URL" ]; then \
				echo "Failed to find podman release for macOS"; exit 1; \
			fi; \
			curl -o /tmp/podman.zip -L "$$RELEASE_URL" && \
			unzip -q /tmp/podman.zip -d "$$(dirname $(PODMAN))" && \
			find "$$(dirname $(PODMAN))" -name podman -type f -exec mv {} $(PODMAN) \; && \
			chmod +x $(PODMAN) && \
			rm /tmp/podman.zip; \
		else \
			echo "podman download for linux not yet supported"; exit 1; \
		fi; \
	}

.PHONY: uv
uv: $(UV) ## Download uv locally if necessary

$(UV): $(LOCALBIN)
	@test -s $(UV) || { mkdir -p $(UV_DIR); curl -LsSf https://astral.sh/uv/$(UV_VERSION)/install.sh | UV_UNMANAGED_INSTALL=$(UV_DIR) sh > /dev/null; }
