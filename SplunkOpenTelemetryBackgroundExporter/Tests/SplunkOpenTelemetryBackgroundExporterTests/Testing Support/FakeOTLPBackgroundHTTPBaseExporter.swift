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

import Foundation
import SplunkCommon
import Testing
import OpenTelemetryProtocolExporterCommon
import CiscoEncryption

@testable import SplunkOpenTelemetryBackgroundExporter

final class FakeOTLPBackgroundHTTPBaseExporter: OTLPBackgroundHTTPBaseExporter {

    var checkStalledUploadsOperationCalled = false

    var checkAndSendCalledWithFiles: [String] = []

    override func checkStalledUploadsOperation(tasks: [URLSessionTask]) {
        checkStalledUploadsOperationCalled = true
        super.checkStalledUploadsOperation(tasks: tasks)
    }

    override func checkAndSend(fileKeys files: [String], existingTasks allTaskDescriptions: [any RequestDescriptorProtocol], cancelTime: Date) {
        checkAndSendCalledWithFiles = files
        super.checkAndSend(fileKeys: files, existingTasks: allTaskDescriptions, cancelTime: cancelTime)
    }
}
