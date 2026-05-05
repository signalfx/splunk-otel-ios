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

/// Polls an async condition until it returns `true` or a timeout is reached.
///
/// - Parameters:
///   - timeout: Maximum time to wait, in seconds. Defaults to 1.0.
///   - pollIntervalNanoseconds: Interval between polls. Defaults to 10 ms.
///   - condition: An async closure that returns `true` when the expected state is reached.
/// - Returns: `true` if the condition was met, `false` if still unmet after timeout.
@_spi(SplunkTesting)
@discardableResult
public func waitUntil(
    timeout: TimeInterval = 1.0,
    pollIntervalNanoseconds: UInt64 = 10_000_000,
    _ condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline, !Task.isCancelled {
        if await condition() {
            return true
        }

        try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }

    // Grace check: condition may have satisfied during the final sleep interval.
    return await condition()
}
