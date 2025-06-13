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
        ScrollView {
            VStack(spacing: 16) {
                DemoHeaderView()

                FeatureSection(title: "Custom Event Tracking") {
                    FeatureButton(label: "Track Event") {
                        trackCustomEvent()
                    }
                }

                FeatureSection(title: "Custom Workflow Tracking") {
                    FeatureButton(label: "Track Workflow (Span)") {
                        trackWorkflow()
                    }
                }

                FeatureSection(title: "Custom Error Tracking") {
                    FeatureButton(label: "Track Error String") {
                        let attributes = SampleAttributes.forStringError()
                        SplunkRum.shared.customTracking.trackError(DemoErrors.stringError(), attributes)
                    }

                    FeatureButton(label: "Track Swift Error type") {
                        let attributes = SampleAttributes.forSwiftError()
                        SplunkRum.shared.customTracking.trackError(DemoErrors.swiftError(), attributes)
                    }

                    FeatureButton(label: "Track NSError") {
                        let attributes = SampleAttributes.forNSError()
                        SplunkRum.shared.customTracking.trackError(DemoErrors.nsError(), attributes)
                    }

                    FeatureButton(label: "Track NSException") {
                        let attributes = SampleAttributes.forNSException()
                        SplunkRum.shared.customTracking.trackException(DemoErrors.nsException(), attributes)
                    }
                }

                Spacer()
            }
        }
        .navigationTitle("Custom Tracking")
    }

    func trackCustomEvent() {
        let attributes = MutableAttributes()
        attributes["UIElementType"] = .string("Button")
        attributes["ActionType"] = .string("Primary Action")
        attributes["Timestamp"] = .string(Date().description)
        attributes["EventID"] = .int(12345)
        SplunkRum.shared.customTracking.trackCustomEvent("Demo Button Clicked", attributes)
    }

    func trackWorkflow() {
        let customSpan = SplunkRum.shared.customTracking.trackWorkflow("Custom Workflow")
        customSpan.setAttribute(key: "test", value: "qwerty")

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            customSpan.end()
        }
    }
}

struct DemoErrors {
    // String error (no stack trace needed)
    static func stringError() -> String {
        "This is a string representing an error message"
    }

    // Swift Error with stack trace
    static func swiftError() -> Error {
        struct SampleError: Error, LocalizedError {
            var errorDescription: String? { "This is a Swift Error" }
        }
        return SampleError()
    }

    // NSError with stack trace
    static func nsError() -> NSError {
        NSError(domain: "com.example.error", code: 42, userInfo: [NSLocalizedDescriptionKey: "This is an NSError"])
    }

    // NSException with stack trace (from callStackSymbols)
    static func nsException() -> NSException {
        // Use the Objective-C helper to trigger and catch an NSException
        let exception = ObjCExceptionHelper.performBlockAndCatchException {
            // Trigger an NSException by calling an unrecognized selector
            NSObject().perform(Selector(("nonExistentMethod")))
        }

        // Ensure the exception was captured
        guard let exception = exception else {
            fatalError("Failed to trigger NSException")
        }

        return exception
    }
}

struct SampleAttributes {
    static func forStringError() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setString("sampleValue", for: "stringKey")
        return attributes
    }

    static func forSwiftError() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setBool(true, for: "isSwiftError")
        attributes.setInt(404, for: "errorCode")
        return attributes
    }

    static func forNSError() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setString("NSErrorDomain", for: "domain")
        attributes.setInt(42, for: "code")
        return attributes
    }

    static func forNSException() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setString("NSExceptionName", for: "exceptionName")
        attributes.setString("Sample reason", for: "reason")
        return attributes
    }
}
