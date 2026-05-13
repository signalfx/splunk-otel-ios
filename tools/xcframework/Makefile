# tools/xcframework/Makefile
#
# Top-level entry point for building, validating, signing, and releasing
# SplunkAgent xcframeworks.
#
# Usage:
#   make build                                     # Build all xcframeworks
#   make build-otel                                # Build only OTel xcframeworks
#   make build-cisco                               # Build dynamic Cisco xcframeworks from local Session Replay checkout
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
#   OTEL_VERSION          - OpenTelemetry Swift Core version (read from Package.swift)
#   SESSION_REPLAY_LOCAL_PATH - Required path to local Session Replay repo for Cisco dynamic xcframeworks
#   CISCO_XCFRAMEWORKS_PATH - Legacy path to prebuilt dynamic Cisco SR xcframeworks directory
#   PLCRASH_VERSION       - PLCrashReporter version (read from Package.swift)
#   SIGNING_IDENTITY      - Code signing identity for codesign
#   VERSION               - Release version number
#   IOS_ONLY              - Set to true to build only iOS device and simulator slices

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
# Dependency versions are read from Package.swift (single source of truth).
# The Package.swift uses `exact:` pins so SPM and xcframework builds always match.
# Override with environment variables if needed (e.g. OTEL_VERSION=2.4.0 make build).
REPO_ROOT    := $(TOOLS_ROOT)/../..
PACKAGE_SWIFT := $(REPO_ROOT)/Package.swift

OTEL_VERSION    ?= $(shell awk '/opentelemetry-swift-core/{found=1} found && !/^ *\/\// && /exact:/{gsub(/.*exact: *"/,""); gsub(/".*/,""); print; exit}' $(PACKAGE_SWIFT))
PLCRASH_VERSION ?= $(shell awk '/plcrashreporter/{found=1} found && !/^ *\/\// && /exact:/{gsub(/.*exact: *"/,""); gsub(/".*/,""); print; exit}' $(PACKAGE_SWIFT))
SIGNING_IDENTITY        ?=
VERSION                 ?=
RELEASE                 ?= false
IOS_ONLY                ?= false
SESSION_REPLAY_LOCAL_PATH ?=
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
	@echo "  SESSION_REPLAY_LOCAL_PATH Required path to local Session Replay repo"
	@echo "  CISCO_XCFRAMEWORKS_PATH   Legacy path to prebuilt dynamic Cisco xcframeworks"
	@echo "  PLCRASH_VERSION           PLCrashReporter version (default: $(PLCRASH_VERSION))"
	@echo "  SIGNING_IDENTITY          Apple code signing identity"
	@echo "  VERSION                   Release version (required for 'make release')"
	@echo "  RELEASE                   Set to 'true' for release-mode validation"
	@echo "  IOS_ONLY                  Set to 'true' to build only iOS device and simulator slices"


## build: Build all xcframeworks (OTel + PLCrash + Cisco + dependencies + Agent modules)
.PHONY: build
build: check-session-replay-path build-otel build-plcrash build-cisco populate-deps build-agent
	@echo ""
	@echo "==> All xcframeworks built successfully"
	@echo "    Output: $(XCFW_DIR)"


## check-session-replay-path: Verify SESSION_REPLAY_LOCAL_PATH is set for dynamic Cisco builds
.PHONY: check-session-replay-path
check-session-replay-path:
ifndef SESSION_REPLAY_LOCAL_PATH
	@echo "ERROR: SESSION_REPLAY_LOCAL_PATH is required for xcframework builds."
	@echo "  Usage: SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay-repo make build"
	@exit 1
endif
	@if [ ! -d "$(SESSION_REPLAY_LOCAL_PATH)" ]; then \
		echo "ERROR: SESSION_REPLAY_LOCAL_PATH does not exist: $(SESSION_REPLAY_LOCAL_PATH)"; \
		exit 1; \
	fi
	@if [ ! -x "$(SESSION_REPLAY_LOCAL_PATH)/Tools/build_frameworks.sh" ]; then \
		echo "ERROR: Session Replay build script is missing or not executable: $(SESSION_REPLAY_LOCAL_PATH)/Tools/build_frameworks.sh"; \
		exit 1; \
	fi


## build-otel: Build OpenTelemetryApi + OpenTelemetrySdk xcframeworks from source
.PHONY: build-otel
build-otel:
	@echo "==> Building OTel xcframeworks..."
	OTEL_VERSION=$(OTEL_VERSION) IOS_ONLY=$(IOS_ONLY) $(SCRIPTS_DIR)/build-otel-xcframeworks.sh


## build-plcrash: Build CrashReporter (PLCrashReporter) xcframework from source
.PHONY: build-plcrash
build-plcrash:
	@echo "==> Building PLCrashReporter xcframework..."
	PLCRASH_VERSION=$(PLCRASH_VERSION) IOS_ONLY=$(IOS_ONLY) $(SCRIPTS_DIR)/build-plcrash-xcframeworks.sh


## build-cisco: Build dynamic Cisco Session Replay xcframeworks from local source
.PHONY: build-cisco
build-cisco:
	@echo "==> Building dynamic Cisco Session Replay xcframeworks..."
	SESSION_REPLAY_LOCAL_PATH="$(SESSION_REPLAY_LOCAL_PATH)" IOS_ONLY=$(IOS_ONLY) $(SCRIPTS_DIR)/build-cisco-xcframeworks.sh


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
	IOS_ONLY=$(IOS_ONLY) $(SCRIPTS_DIR)/build-xcframeworks.sh


## sign: Sign all built xcframeworks (optional locally, mandatory for release)
.PHONY: sign
sign:
ifndef SIGNING_IDENTITY
	@echo "ERROR: SIGNING_IDENTITY is required for signing."
	@echo "  Usage: make sign SIGNING_IDENTITY=\"Apple Distribution: Splunk Inc.\""
	@exit 1
endif
	@echo "==> Signing xcframeworks..."
	$(SCRIPTS_DIR)/sign-xcframeworks.sh --include-cisco "$(SIGNING_IDENTITY)"


## validate: Validate all built xcframeworks (structure, slices, interfaces)
.PHONY: validate
validate:
	@echo "==> Validating xcframeworks..."
	RELEASE=$(RELEASE) IOS_ONLY=$(IOS_ONLY) $(SCRIPTS_DIR)/validate-xcframeworks.sh


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
	$(MAKE) build IOS_ONLY="$(IOS_ONLY)"
	$(MAKE) sign SIGNING_IDENTITY="$(SIGNING_IDENTITY)"
	$(MAKE) validate RELEASE=true IOS_ONLY="$(IOS_ONLY)"
	IOS_ONLY=$(IOS_ONLY) $(SCRIPTS_DIR)/release.sh "$(VERSION)"


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
