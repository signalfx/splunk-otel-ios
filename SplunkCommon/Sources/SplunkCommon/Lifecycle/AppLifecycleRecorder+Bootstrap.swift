//
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

/// C-compatible entry point used by the private load-time bootstrap target.
///
/// The constructor itself stays free of UIKit and telemetry work; this function
/// only initializes the shared, bounded lifecycle recorder.
@_cdecl("splunk_rum_bootstrap_lifecycle_recording")
public func splunkRumBootstrapLifecycleRecording() {
    _ = AppLifecycleRecorder.bootstrap()
}
