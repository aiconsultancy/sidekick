# Sidekick - Makefile for building and releasing
SHELL := /bin/bash

# Version
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
RELEASE_VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.1.0")

# Directories
BUILD_DIR := build
DIST_DIR := dist
RELEASE_NAME := sidekick-$(RELEASE_VERSION)
RELEASE_TAR := $(RELEASE_NAME).tar.gz

# GitHub release info
GITHUB_OWNER ?= $(shell git remote get-url origin | sed -E 's/.*[:/]([^/]+)\/[^/]+\.git/\1/')
GITHUB_REPO ?= $(shell git remote get-url origin | sed -E 's/.*\/([^/]+)\.git/\1/')

.PHONY: all clean test install release release-tar release-github help version

all: help

help: ## Show this help message
	@echo "Sidekick Makefile"
	@echo "================="
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "Current version: $(VERSION)"
	@echo "Release version: $(RELEASE_VERSION)"

version: ## Display current version
	@echo "Current version: $(VERSION)"
	@echo "Release version: $(RELEASE_VERSION)"

clean: ## Clean build artifacts
	rm -rf $(BUILD_DIR) $(DIST_DIR)

test: ## Run test suite
	@echo "Running tests..."
	@bash run_tests.sh

install: ## Install sidekick locally (user directory)
	@echo "Installing sidekick to ~/.local/bin..."
	@mkdir -p ~/.local/share/sidekick
	@mkdir -p ~/.local/bin
	@cp -r sidekick plugins lib ~/.local/share/sidekick/
	@if [ -d schema ]; then cp -r schema ~/.local/share/sidekick/; fi
	@cp VERSION ~/.local/share/sidekick/ 2>/dev/null || echo "v0.1.0" > ~/.local/share/sidekick/VERSION
	@ln -sf ~/.local/share/sidekick/sidekick ~/.local/bin/sidekick
	@echo "Sidekick installed successfully!"
	@if echo "$$PATH" | grep -q "$$HOME/.local/bin"; then \
		echo "Run 'sidekick --help' to get started"; \
	else \
		echo "Add ~/.local/bin to your PATH:"; \
		echo "  export PATH=\"$$HOME/.local/bin:$$PATH\""; \
		echo "Then run 'sidekick --help' to get started"; \
	fi

install-system: ## Install sidekick system-wide (requires sudo)
	@echo "Installing sidekick to /usr/local/bin..."
	@sudo mkdir -p /usr/local/share/sidekick
	@sudo mkdir -p /usr/local/bin
	@sudo cp -r sidekick plugins lib /usr/local/share/sidekick/
	@if [ -d schema ]; then sudo cp -r schema /usr/local/share/sidekick/; fi
	@sudo cp VERSION /usr/local/share/sidekick/ 2>/dev/null || echo "v0.1.0" | sudo tee /usr/local/share/sidekick/VERSION > /dev/null
	@sudo ln -sf /usr/local/share/sidekick/sidekick /usr/local/bin/sidekick
	@echo "Sidekick installed successfully!"
	@echo "Run 'sidekick --help' to get started"

release-tar: clean ## Create release tarball
	@echo "Creating release tarball $(RELEASE_TAR)..."
	@mkdir -p $(DIST_DIR)
	@mkdir -p $(BUILD_DIR)/$(RELEASE_NAME)
	
	# Copy core files
	@cp -r sidekick plugins lib $(BUILD_DIR)/$(RELEASE_NAME)/
	@cp README.md LICENSE* $(BUILD_DIR)/$(RELEASE_NAME)/ 2>/dev/null || true
	
	# Copy schema if it exists
	@if [ -d schema ]; then cp -r schema $(BUILD_DIR)/$(RELEASE_NAME)/; fi
	
	# Create version file
	@echo "$(RELEASE_VERSION)" > $(BUILD_DIR)/$(RELEASE_NAME)/VERSION
	
	# Create tarball
	@tar -czf $(DIST_DIR)/$(RELEASE_TAR) -C $(BUILD_DIR) $(RELEASE_NAME)
	@echo "Release tarball created: $(DIST_DIR)/$(RELEASE_TAR)"
	
	# Calculate checksums
	@cd $(DIST_DIR) && sha256sum $(RELEASE_TAR) > $(RELEASE_TAR).sha256
	@echo "Checksum created: $(DIST_DIR)/$(RELEASE_TAR).sha256"

release-github: release-tar ## Create GitHub release
	@echo "Creating GitHub release $(RELEASE_VERSION)..."
	@if ! command -v gh &> /dev/null; then \
		echo "Error: GitHub CLI (gh) is required but not installed"; \
		exit 1; \
	fi
	
	# Check if release already exists
	@if gh release view $(RELEASE_VERSION) --repo $(GITHUB_OWNER)/$(GITHUB_REPO) &>/dev/null; then \
		echo "Release $(RELEASE_VERSION) already exists. Delete it first or bump version."; \
		exit 1; \
	fi
	
	# Create release
	@gh release create $(RELEASE_VERSION) \
		--repo $(GITHUB_OWNER)/$(GITHUB_REPO) \
		--title "Sidekick $(RELEASE_VERSION)" \
		--notes "Release $(RELEASE_VERSION) of Sidekick - Extensible Development Workflow Tool" \
		$(DIST_DIR)/$(RELEASE_TAR) \
		$(DIST_DIR)/$(RELEASE_TAR).sha256 \
		install.sh
	
	@echo "GitHub release created successfully!"
	@echo "Users can now install with:"
	@echo "  curl -sSL https://github.com/$(GITHUB_OWNER)/$(GITHUB_REPO)/releases/download/$(RELEASE_VERSION)/install.sh | bash"

release: test release-github ## Run tests and create GitHub release
	@echo "Release $(RELEASE_VERSION) completed!"

tag: ## Create git tag for release
	@echo "Creating git tag $(RELEASE_VERSION)..."
	@git tag -a $(RELEASE_VERSION) -m "Release $(RELEASE_VERSION)"
	@echo "Tag created. Push with: git push origin $(RELEASE_VERSION)"

bump-patch: ## Bump patch version (e.g., v1.0.0 -> v1.0.1)
	@current=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	new=$$(echo $$current | awk -F. '{print $$1"."$$2"."$$3+1}'); \
	echo "Bumping version from $$current to $$new"; \
	git tag -a $$new -m "Release $$new"

bump-minor: ## Bump minor version (e.g., v1.0.0 -> v1.1.0)
	@current=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	new=$$(echo $$current | awk -F. '{print $$1"."$$2+1".0"}'); \
	echo "Bumping version from $$current to $$new"; \
	git tag -a $$new -m "Release $$new"

bump-major: ## Bump major version (e.g., v1.0.0 -> v2.0.0)
	@current=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	new=$$(echo $$current | awk -F. '{v=substr($$1,2); print "v"v+1".0.0"}'); \
	echo "Bumping version from $$current to $$new"; \
	git tag -a $$new -m "Release $$new"

.DEFAULT_GOAL := help