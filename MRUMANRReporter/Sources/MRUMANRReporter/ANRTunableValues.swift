//
/*
Copyright 2024 Splunk Inc.

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


/// Internal tunable values for ANR checking
///
/// Encapsulate values that are "tune once" during our initial development and not exposed for configuration.
/// After their initial tuning, we do not expect to change these again.

internal struct ANRTunableValues {


    // MARK: Internal

    /// How often the main thread attempts to update the isMainThreadResponsive flag.
    internal let heartbeatInterval: TimeInterval = 0.1

    /// How often (but with some leeway) we check on the flag from the background queue, fractional seconds.
    internal let checkInterval: Double = 0.15

    /// How much leeway we allow the system for when to run the check. Helps reduce our performance impact.
    internal let checkLeewayMS: Int = 100

    /// Duration after which we give up measuring and report the ANR even though it might still be ongoing.
    internal let maxANRDuration: TimeInterval = 10.0
}
