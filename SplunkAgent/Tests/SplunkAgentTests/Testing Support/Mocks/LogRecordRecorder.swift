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
import OpenTelemetrySdk

/// A log record processor that records the log records it is given.
final class LogRecordRecorder: LogRecordProcessor {

    private(set) var records: [ReadableLogRecord] = []

    func onEmit(logRecord: ReadableLogRecord) {
        records.append(logRecord)
    }

    func forceFlush(explicitTimeout _: TimeInterval?) -> ExportResult {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) -> ExportResult {
        .success
    }
}
