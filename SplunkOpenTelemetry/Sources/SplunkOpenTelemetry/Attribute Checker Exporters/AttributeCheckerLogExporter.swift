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
import OpenTelemetrySdk
import SplunkLogger

class AttributeCheckerLogExporter: LogRecordExporter {

    // MARK: - Private

    // No required attributes currently
    private let requiredAttributes: [String] = []

    private let proxyExporter: LogRecordExporter

    private let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk RUM OTel", category: "LogAttributeChecker"))


    // MARK: - Initialization

    init(proxy: LogRecordExporter) {
        proxyExporter = proxy
    }


    // MARK: - LogRecordExporter

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        check(logs: logRecords)

        return proxyExporter.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        proxyExporter.shutdown(explicitTimeout: explicitTimeout)
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        proxyExporter.forceFlush(explicitTimeout: explicitTimeout)
    }

    // MARK: - Check

    private func check(logs: [ReadableLogRecord]) {
        for log in logs {
            for requiredAttribute in requiredAttributes {
                guard let _ = log.attributes[requiredAttribute] else {
                    internalLogger.log(level: .error) {
                        """
                        ‼️‼️‼️ LogRecord is missing a required attribute: \"\(requiredAttribute)\" 
                        Attributes: \(log.attributes)
                        """
                    }

                    continue
                }
            }
        }
    }
}
