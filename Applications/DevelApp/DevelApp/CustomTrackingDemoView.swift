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

import SplunkAgent
import SwiftUI

struct CustomTrackingDemoView: View {
    var body: some View {
        VStack {
            DemoHeaderView()

            // Button for tracking a custom event
            Button("Track Event") {
                trackCustomEvent()
            }
            .padding()

            // Button for tracking an error (String message)
            Button("Track Error (String)") {
                trackErrorString()
            }
            .padding()

            // Button for tracking an Error (Swift conforming type)
            Button("Track Error (Error)") {
                trackErrorType()
            }
            .padding()

            // Button for tracking an NSError
            Button("Track Error (NSError)") {
                trackNSError()
            }
            .padding()

            // Button for tracking an NSException
            Button("Track Exception (NSException)") {
                trackNSException()
            }
            .padding()

            // Button for tracking a Workflow
            Button("Track Workflow (Span)") {
                trackWorkflow()
            }
            .padding()

            Spacer()
        }
        .navigationTitle("Custom Tracking")
        .padding()
    }


    // MARK: - Custom Tracking Functions

    func trackCustomEvent() {
        let attributes = MutableAttributes()
        attributes["UIElementType"] = .string("Button")
        attributes["ActionType"] = .string("Primary Action")
        attributes["Timestamp"] = .string(Date().description)
        attributes["EventID"] = .int(12345)
        SplunkRum.shared.customTracking.trackCustomEvent("Demo Button Clicked", attributes)
    }

    func trackErrorString() {
        let attributes = MutableAttributes()
        attributes["ErrorType"] = .string("StringError")
        attributes["ErrorSeverity"] = .string("Critical")
        SplunkRum.shared.customTracking.trackError("This is a sample string error", attributes)
    }

    func trackErrorType() {
        let attributes = MutableAttributes()
        attributes["ErrorType"] = .string("SwiftError")
        attributes["ErrorCode"] = .int(404)
        let sampleError: Error = NSError(domain: "com.example.error", code: 100, userInfo: [NSLocalizedDescriptionKey: "Sample Swift error"])
        SplunkRum.shared.customTracking.trackError(sampleError, attributes)
    }

    func trackNSError() {
        let attributes = MutableAttributes()
        attributes["ErrorDomain"] = .string("com.example.nserror")
        attributes["ErrorCode"] = .int(200)
        attributes["Description"] = .string("Sample NSError description")
        let nsError = NSError(domain: "com.example.nserror", code: 200, userInfo: [NSLocalizedDescriptionKey: "Sample NSError"])
        SplunkRum.shared.customTracking.trackError(nsError, attributes)
    }

    func trackNSException() {
        let attributes = MutableAttributes()
        attributes["ExceptionName"] = .string("GenericException")
        attributes["Reason"] = .string("Sample NSException reason")
        attributes["Handled"] = .bool(true)
        let exception = NSException(name: .genericException, reason: "Sample NSException reason", userInfo: ["Key": "Value"])
        SplunkRum.shared.customTracking.trackException(exception, attributes)
    }

    func trackWorkflow() {
        let customSpan = SplunkRum.shared.customTracking.trackWorkflow("Custom Workflow")
        customSpan.setAttribute(key: "test", value: "qwerty")

        // End span after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                customSpan.end()
        }
    }
}
