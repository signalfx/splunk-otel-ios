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

import CiscoEncryption
import Foundation
import OpenTelemetryProtocolExporterCommon
import SplunkCommon
@testable import SplunkOpenTelemetryBackgroundExporter
import Testing

final class MockOTLPBackgroundHTTPBaseExporter: OTLPBackgroundHTTPBaseExporter {

    var checkStalledUploadsOperationCalled = false

    var checkAndSendCalledWithFiles: [String] = []

    override func checkStalledUploadsOperation(tasks: [URLSessionTask]) {
        checkStalledUploadsOperationCalled = true
        super.checkStalledUploadsOperation(tasks: tasks)
    }

    override func checkAndSend(fileKeys files: [String], existingTasks allTaskDescriptions: [any RequestDescriptorProtocol], cancelledTaskIds: Set<UUID>) {
        checkAndSendCalledWithFiles = files
        super.checkAndSend(fileKeys: files, existingTasks: allTaskDescriptions, cancelledTaskIds: cancelledTaskIds)
    }
}
