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

import Foundation

/// Span names, attribute keys, and attribute values used by network monitor instrumentation.
///
/// Standard network connection keys should use ``SemanticConventions/Network`` where applicable.
enum NetworkMonitorSpanAttributes {

    // MARK: - Span identity

    /// OpenTelemetry tracer instrumentation scope name.
    static let instrumentationName = "NetworkMonitor"

    /// Span name for network connectivity change events.
    static let spanName = "network.change"


    // MARK: - Splunk-specific attribute keys

    /// Connectivity status (`available` or `lost`).
    static let networkStatus = "network.status"


    // MARK: - Attribute values

    /// Value for ``networkStatus`` when the device has network connectivity.
    static let statusValueAvailable = "available"

    /// Value for ``networkStatus`` when network connectivity is lost.
    static let statusValueLost = "lost"

    /// Placeholder used in debug logging when no radio subtype is available.
    static let debugRadioTypeUnavailable = "na"
}
