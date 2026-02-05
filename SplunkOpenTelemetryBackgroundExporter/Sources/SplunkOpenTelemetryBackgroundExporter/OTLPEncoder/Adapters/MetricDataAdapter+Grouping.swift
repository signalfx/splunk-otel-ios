//
//
/*
Copyright 2025 Splunk Inc.

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

import OpenTelemetryApi
import OpenTelemetrySdk

extension MetricDataAdapter {

    // MARK: - Private Grouping Methods

    /// Groups metrics by resource.
    static func groupByResource(_ metrics: [MetricData]) -> [Resource: [MetricData]] {
        var result: [Resource: [MetricData]] = [:]

        for metric in metrics {
            result[metric.resource, default: []].append(metric)
        }

        return result
    }

    /// Groups metrics by instrumentation scope within a resource.
    static func groupByScope(_ metrics: [MetricData]) -> [ScopeKey: [MetricData]] {
        var result: [ScopeKey: [MetricData]] = [:]

        for metric in metrics {
            let key = ScopeKey(from: metric.instrumentationScopeInfo)
            result[key, default: []].append(metric)
        }

        return result
    }
}
