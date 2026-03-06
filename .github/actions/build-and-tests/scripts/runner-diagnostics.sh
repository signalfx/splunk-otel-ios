#!/usr/bin/env bash
set -uo pipefail

echo "::group::Runner and Xcode diagnostics"

FAILED=0
RUNNER_IMAGE_OS="${ImageOS:-unknown}"
RUNNER_IMAGE_VERSION="${ImageVersion:-unknown}"
RUN_ID="${GITHUB_RUN_ID:-unknown}"
RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-unknown}"
JOB_NAME="${GITHUB_JOB:-unknown}"
RUNNER_LABEL="${RUNNER_NAME:-unknown}"
RUNNER_OS_NAME="${RUNNER_OS:-unknown}"
RUNNER_ARCH_NAME="${RUNNER_ARCH:-unknown}"
MACOS_PRODUCT_VERSION="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
MACOS_BUILD_VERSION="$(sw_vers -buildVersion 2>/dev/null || echo unknown)"

LATEST_IPHONESIMULATOR_SDK="$(
  xcodebuild -showsdks 2>/dev/null \
    | awk '
        /-sdk iphonesimulator[0-9.]+/ {
          if (match($0, /iphonesimulator[0-9.]+/)) {
            sdk = substr($0, RSTART + 14, RLENGTH - 14)
            if (sdk != "") print sdk
          }
        }
      ' \
    | sort -V \
    | tail -n1
)"

LATEST_IOS_RUNTIME="$(
  xcrun simctl list runtimes 2>/dev/null \
    | awk '
        /^iOS [0-9.]+/ && $0 !~ /\(unavailable/ {
          if (match($0, /^iOS [0-9.]+/)) {
            runtime = substr($0, 5, RLENGTH - 4)
            if (runtime != "") print runtime
          }
        }
      ' \
    | sort -V \
    | tail -n1
)"

LATEST_IOS_RUNTIME_WITH_DEVICE="$(
  xcrun simctl list devices available 2>/dev/null \
    | awk '
        /^-- iOS [0-9.]+ --$/ {
          if (match($0, /^-- iOS [0-9.]+ --$/)) {
            header = substr($0, 7, RLENGTH - 11)
            current_runtime = header
          }
          next
        }
        /^[[:space:]]+iPhone/ {
          if (current_runtime != "") {
            print current_runtime
          }
        }
      ' \
    | sort -Vu \
    | tail -n1
)"

FIRST_DEVICE_ON_LATEST_RUNTIME="$(
  xcrun simctl list devices available 2>/dev/null \
    | awk -v runtime="$LATEST_IOS_RUNTIME_WITH_DEVICE" '
        runtime == "" { exit }
        $0 == "-- iOS " runtime " --" { in_target = 1; next }
        /^-- / { in_target = 0 }
        in_target && /^[[:space:]]+iPhone/ {
          line = $0
          sub(/^[[:space:]]+/, "", line)
          sub(/ \([0-9A-F-]+\).*/, "", line)
          print line
          exit
        }
      '
)"

echo "::notice::[runner-diagnostics] run_id=${RUN_ID} attempt=${RUN_ATTEMPT} job=${JOB_NAME} runner_name=${RUNNER_LABEL} runner_os=${RUNNER_OS_NAME} runner_arch=${RUNNER_ARCH_NAME}"
echo "::notice::[runner-diagnostics] image_os=${RUNNER_IMAGE_OS} image_version=${RUNNER_IMAGE_VERSION} macos_version=${MACOS_PRODUCT_VERSION} macos_build=${MACOS_BUILD_VERSION}"
echo "::notice::[runner-diagnostics] latest_sdk_iphonesimulator=${LATEST_IPHONESIMULATOR_SDK:-unknown} latest_ios_runtime_available=${LATEST_IOS_RUNTIME:-unknown} latest_ios_runtime_with_device=${LATEST_IOS_RUNTIME_WITH_DEVICE:-unknown} sample_device_on_latest_runtime=${FIRST_DEVICE_ON_LATEST_RUNTIME:-none}"

if [ -n "${LATEST_IPHONESIMULATOR_SDK:-}" ] \
  && [ -n "${LATEST_IOS_RUNTIME:-}" ] \
  && [ "$LATEST_IPHONESIMULATOR_SDK" != "$LATEST_IOS_RUNTIME" ]; then
  echo "::warning::[runner-diagnostics] latest SDK/runtime mismatch: iphonesimulator SDK=$LATEST_IPHONESIMULATOR_SDK runtime=$LATEST_IOS_RUNTIME"
fi

run_diagnostic() {
  local command="$1"
  local status=0

  echo "[runner-diagnostics] $command"
  if bash -lc "$command"; then
    :
  else
    status=$?
    FAILED=1
    echo "::warning::[runner-diagnostics] Command failed (exit $status): $command"
  fi
  echo
}

run_diagnostic "xcodebuild -version"
run_diagnostic "xcode-select -p"
run_diagnostic "find /Applications -maxdepth 1 -type d -name \"Xcode*.app\" -print"
run_diagnostic "xcodebuild -showsdks"
run_diagnostic "xcrun simctl list runtimes"
run_diagnostic "xcrun simctl list devices available"

if [ "$FAILED" -ne 0 ]; then
  echo "::warning::[runner-diagnostics] One or more diagnostics commands failed"
fi

echo "::endgroup::"
