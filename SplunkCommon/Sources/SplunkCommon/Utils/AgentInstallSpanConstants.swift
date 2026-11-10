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

/// Shared identifiers for the span that reports the agent installation.
///
/// The App Start module sends this span as a child of a cold `AppStart` span.
/// The span name is customer-visible telemetry.
package enum AgentInstallSpanConstants {

    /// Name of the span that reports the agent installation.
    ///
    /// The Splunk RUM Android agent uses the same name from version 2.4.0 on.
    package static let spanName = "SplunkRum.install"
}
