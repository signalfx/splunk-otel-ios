# tools/xcframework/Makefile
#
# Top-level entry point for building, validating, signing, and releasing
# SplunkAgent xcframeworks.
#
# Usage:
#   make build                                     # Build all xcframeworks
#   make build-otel                                # Build only OTel xcframeworks
#   make build-agent                               # Build only SplunkAgent xcframeworks
#   make sign SIGNING_IDENTITY="Apple Distribution: Splunk Inc."  # Sign all xcframeworks
#   make validate                                  # Validate all xcframeworks
#   make validate RELEASE=true                     # Validate with signature check
#   make release VERSION=1.0.0 SIGNING_IDENTITY="..." # Full release pipeline
#   make check-sync                                # Check Package.swift / Project.swift sync
#   make clean                                     # Remove all build artifacts
#
# Prerequisites:
#   - Xcode 16+ with command-line tools
#   - Tuist (brew install tuist)
#   - git
#
# Environment Variables:
#   OTEL_VERSION          - OpenTelemetry Swift Core version (default: 2.3.0)
#   CISCO_XCFRAMEWORKS_PATH - Path to Cisco SR xcframeworks directory
#   PLCRASH_VERSION       - PLCrashReporter version (default: 1.12.0)
#   SIGNING_IDENTITY      - Code signing identity for codesign
#   VERSION               - Release version number

SHELL := /bin/bash
.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Directories
# ---------------------------------------------------------------------------
TOOLS_ROOT   := $(shell pwd)
SCRIPTS_DIR  := $(TOOLS_ROOT)/scripts
OUTPUT_DIR   := $(TOOLS_ROOT)/output
XCFW_DIR     := $(OUTPUT_DIR)/xcframeworks
BUILD_DIR    := $(TOOLS_ROOT)/build
DEPS_DIR     := $(TOOLS_ROOT)/dependencies

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
OTEL_VERSION       ?= 2.3.0
PLCRASH_VERSION    ?= 1.12.0
SIGNING_IDENTITY   ?=
VERSION            ?=
RELEASE            ?= false
CISCO_XCFRAMEWORKS_PATH ?=

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

## help: Show this help message
.PHONY: help
help:
	@echo "XCFramework Build System for SplunkAgent iOS SDK"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [VARIABLE=value ...]"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /' | column -t -s ':'
	@echo ""
	@echo "Variables:"
	@echo "  OTEL_VERSION              OTel Swift Core version (default: $(OTEL_VERSION))"
	@echo "  CISCO_XCFRAMEWORKS_PATH   Path to Cisco Session Replay xcframeworks"
	@echo "  PLCRASH_VERSION           PLCrashReporter version (default: $(PLCRASH_VERSION))"
	@echo "  SIGNING_IDENTITY          Apple code signing identity"
	@echo "  VERSION                   Release version (required for 'make release')"
	@echo "  RELEASE                   Set to 'true' for release-mode validation"


## build: Build all xcframeworks (OTel + PLCrash + dependencies + Agent modules)
.PHONY: build
build: build-otel build-plcrash populate-deps build-agent
	@echo ""
	@echo "==> All xcframeworks built successfully"
	@echo "    Output: $(XCFW_DIR)"


## build-otel: Build OpenTelemetryApi + OpenTelemetrySdk xcframeworks from source
.PHONY: build-otel
build-otel:
	@echo "==> Building OTel xcframeworks..."
	OTEL_VERSION=$(OTEL_VERSION) $(SCRIPTS_DIR)/build-otel-xcframeworks.sh


## build-plcrash: Build CrashReporter (PLCrashReporter) xcframework from source
.PHONY: build-plcrash
build-plcrash:
	@echo "==> Building PLCrashReporter xcframework..."
	PLCRASH_VERSION=$(PLCRASH_VERSION) $(SCRIPTS_DIR)/build-plcrash-xcframeworks.sh


## populate-deps: Populate dependencies/ directory with pre-built xcframeworks
.PHONY: populate-deps
populate-deps:
	@echo "==> Populating dependencies..."
	$(SCRIPTS_DIR)/populate-dependencies.sh \
		$(if $(CISCO_XCFRAMEWORKS_PATH),--cisco-path "$(CISCO_XCFRAMEWORKS_PATH)",)


## build-agent: Build all SplunkAgent module xcframeworks
.PHONY: build-agent
build-agent:
	@echo "==> Building SplunkAgent module xcframeworks..."
	$(SCRIPTS_DIR)/build-xcframeworks.sh


## sign: Sign all built xcframeworks (optional locally, mandatory for release)
.PHONY: sign
sign:
ifndef SIGNING_IDENTITY
	@echo "ERROR: SIGNING_IDENTITY is required for signing."
	@echo "  Usage: make sign SIGNING_IDENTITY=\"Apple Distribution: Splunk Inc.\""
	@exit 1
endif
	@echo "==> Signing xcframeworks..."
	$(SCRIPTS_DIR)/sign-xcframeworks.sh "$(SIGNING_IDENTITY)"


## validate: Validate all built xcframeworks (structure, slices, interfaces)
.PHONY: validate
validate:
	@echo "==> Validating xcframeworks..."
	RELEASE=$(RELEASE) $(SCRIPTS_DIR)/validate-xcframeworks.sh


## release: Full release pipeline (build + sign + validate + package)
.PHONY: release
release:
ifndef VERSION
	@echo "ERROR: VERSION is required for release."
	@echo "  Usage: make release VERSION=1.0.0 SIGNING_IDENTITY=\"...\""
	@exit 1
endif
ifndef SIGNING_IDENTITY
	@echo "ERROR: SIGNING_IDENTITY is required for release."
	@echo "  Usage: make release VERSION=1.0.0 SIGNING_IDENTITY=\"...\""
	@exit 1
endif
	@echo "==> Starting release pipeline for version $(VERSION)..."
	$(MAKE) build
	$(MAKE) sign SIGNING_IDENTITY="$(SIGNING_IDENTITY)"
	$(MAKE) validate RELEASE=true
	$(SCRIPTS_DIR)/release.sh "$(VERSION)"


## smoke-test: Build smoke test app to verify all xcframeworks link correctly
.PHONY: smoke-test
smoke-test:
	@echo "==> Running smoke test..."
	$(SCRIPTS_DIR)/run-smoke-test.sh


## check-sync: Verify Package.swift and Project.swift targets are in sync
.PHONY: check-sync
check-sync:
	@echo "==> Checking manifest sync..."
	$(SCRIPTS_DIR)/check-manifest-sync.sh


## clean: Remove all build artifacts, generated projects, and dependencies
.PHONY: clean
clean:
	@echo "==> Cleaning..."
	rm -rf $(BUILD_DIR)
	rm -rf $(OUTPUT_DIR)
	rm -rf $(DEPS_DIR)
	rm -rf $(TOOLS_ROOT)/otel/vendor
	rm -rf $(TOOLS_ROOT)/otel/build
	rm -rf $(TOOLS_ROOT)/plcrash/vendor
	rm -rf $(TOOLS_ROOT)/plcrash/build
	# Remove Tuist-generated Xcode projects/workspaces
	rm -rf $(TOOLS_ROOT)/*.xcodeproj
	rm -rf $(TOOLS_ROOT)/*.xcworkspace
	rm -rf $(TOOLS_ROOT)/otel/*.xcodeproj
	rm -rf $(TOOLS_ROOT)/otel/*.xcworkspace
	rm -rf $(TOOLS_ROOT)/plcrash/*.xcodeproj
	rm -rf $(TOOLS_ROOT)/plcrash/*.xcworkspace
	rm -rf $(TOOLS_ROOT)/Derived
	rm -rf $(TOOLS_ROOT)/otel/Derived
	rm -rf $(TOOLS_ROOT)/plcrash/Derived
	@echo "==> Clean complete"
