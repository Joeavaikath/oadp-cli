# Makefile for OADP CLI
# 
# Simple Makefile for building, testing, and installing the OADP CLI

# Variables
BINARY_NAME = kubectl-oadp
INSTALL_PATH ?= /usr/local/bin

# Platform variables for multi-arch builds
# Usage: make build PLATFORM=linux/amd64
PLATFORM ?= 
GOOS = $(word 1,$(subst /, ,$(PLATFORM)))
GOARCH = $(word 2,$(subst /, ,$(PLATFORM)))

# Default target
.PHONY: help
help: ## Show this help message
	@echo "OADP CLI Makefile"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Build with different platforms:"
	@echo "  make build PLATFORM=linux/amd64"
	@echo "  make build PLATFORM=linux/arm64"
	@echo "  make build PLATFORM=darwin/amd64"
	@echo "  make build PLATFORM=darwin/arm64"
	@echo "  make build PLATFORM=windows/amd64"

# Build targets
.PHONY: build
build: ## Build the kubectl plugin binary (use PLATFORM=os/arch for cross-compilation)
	@if [ -n "$(PLATFORM)" ]; then \
		echo "Building $(BINARY_NAME) for $(PLATFORM)..."; \
		GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(BINARY_NAME)-$(GOOS)-$(GOARCH) .; \
		echo "✅ Built $(BINARY_NAME)-$(GOOS)-$(GOARCH) successfully!"; \
	else \
		echo "Building $(BINARY_NAME) for current platform ($$(go env GOOS)/$$(go env GOARCH))..."; \
		go build -o $(BINARY_NAME) .; \
		echo "✅ Built $(BINARY_NAME) successfully!"; \
	fi

# Installation targets
.PHONY: install
install: build ## Build and install the kubectl plugin
	@echo "Installing $(BINARY_NAME) to $(INSTALL_PATH)..."
	mv $(BINARY_NAME) $(INSTALL_PATH)/
	@echo "✅ $(BINARY_NAME) installed successfully!"
	@echo "You can now use: kubectl oadp --help"

# Testing targets
.PHONY: test
test: ## Run all tests
	@echo "Running tests..."
	go test ./...
	@echo "✅ Tests completed!"

.PHONY: test-e2e
test-e2e: ## Run e2e tests with DPA creation (requires AWS credentials and OADP operator)
	@echo "Running e2e tests with DPA creation..."
	@echo "⚠️  This requires AWS credentials and OADP operator to be installed"
	@echo "   Required environment variables:"
	@echo "   - OADP_CRED_FILE   # Path to AWS credentials file"
	@echo "   - OADP_BUCKET      # S3 bucket name for backups"
	@echo "   - CI_CRED_FILE     # Path to CI credentials file"
	@echo "   - VSL_REGION       # AWS region for backup storage"
	cd tests/e2e && go test -v -ginkgo.v --timeout=10m
	@echo "✅ E2E tests completed!"

.PHONY: test-e2e-focus
test-e2e-focus: ## Run e2e tests with focus on specific tests
	@echo "Running focused e2e tests..."
	cd tests/e2e && go test -v -ginkgo.v -ginkgo.focus="$(FOCUS)" --timeout=10m
	@echo "✅ Focused E2E tests completed!"

# Cleanup targets
.PHONY: clean
clean: ## Remove built binaries
	@echo "Cleaning up..."
	@rm -f $(BINARY_NAME) $(BINARY_NAME)-*
	@echo "✅ Cleanup complete!"

# Status and utility targets
.PHONY: status
status: ## Show build status and installation info
	@echo "=== OADP CLI Status ==="
	@echo ""
	@echo "📁 Repository:"
	@pwd
	@echo ""
	@echo "🔧 Local binary:"
	@ls -la $(BINARY_NAME) 2>/dev/null || echo "  No local binary found"
	@echo ""
	@echo "📦 Installed plugin:"
	@ls -la $(INSTALL_PATH)/$(BINARY_NAME) 2>/dev/null || echo "  Plugin not installed"
	@echo ""
	@echo "✅ Plugin accessibility:"
	@if kubectl plugin list 2>/dev/null | grep -q "kubectl-oadp"; then \
		echo "  ✅ kubectl-oadp plugin is installed and accessible"; \
		echo "  Version check:"; \
		kubectl oadp version 2>/dev/null || echo "    (version command not available)"; \
	else \
		echo "  ❌ kubectl-oadp plugin is NOT accessible"; \
		echo "  Available plugins:"; \
		kubectl plugin list 2>/dev/null | head -5 || echo "    (no plugins found or kubectl not available)"; \
	fi
