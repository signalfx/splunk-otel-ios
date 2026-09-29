/*
Copyright 2026 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// The Swift package cannot rely on a Swift-only global initializer to observe
// UIApplication notifications before a hybrid integration calls install().
// Keep this target intentionally tiny: the constructor only calls the
// C-compatible entry point exported by SplunkCommon. The C shim does not access
// UIKit or telemetry APIs directly; the Swift entry point owns idempotent
// recorder initialization. The Swift link anchor keeps this object reachable
// in the supported static product packaging.
#include "SplunkAgentBootstrap.h"

extern void splunk_rum_bootstrap_lifecycle_recording(void);

void splunk_rum_link_lifecycle_bootstrap(void) {}

__attribute__((constructor))
static void splunk_rum_initialize_lifecycle_recording(void) {
    splunk_rum_bootstrap_lifecycle_recording();
}
