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

                    FeatureButton(label: "Track NSError Subclass") {
                        let attributes = SampleAttributes.forNSErrorSubclass()
                        SplunkRum.shared.customTracking.trackError(DemoErrors.nsErrorSubclass(), attributes)
                    }

                    FeatureButton(label: "Track NSException") {
                        let attributes = SampleAttributes.forNSException()
                        SplunkRum.shared.customTracking.trackException(DemoErrors.nsException(), attributes)
                    }
                }

                FeatureSection(title: "Legacy Tracking") {
                    FeatureButton(label: "Track Legacy Error (String)") {
                        trackLegacyErrorString()
                    }

                    FeatureButton(label: "Track Legacy Error") {
                        trackLegacyError()
                    }

                    FeatureButton(label: "Track Legacy NSError") {
                        trackLegacyNSError()
                    }

                    FeatureButton(label: "Track Legacy Exception") {
                        trackLegacyException()
                    }

                    FeatureButton(label: "Track Legacy Event") {
                        trackLegacyEvent()
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

    // MARK: - Legacy API calls demonstrating available but deprecated methods


    /// Note: Deprecation warnings in the next section are an intentional feature of the demo.

    func trackLegacyErrorString() {
        let message = "Legacy error string"
        SplunkRum.reportError(string: message)
    }

    func trackLegacyError() {
        let sampleError: Error = NSError(domain: "com.example.error", code: 100, userInfo: [NSLocalizedDescriptionKey: "Legacy Swift error"])
        SplunkRum.reportError(error: sampleError)
    }

    func trackLegacyNSError() {
        let nsError = NSError(domain: "com.example.nserror", code: 200, userInfo: [NSLocalizedDescriptionKey: "Legacy NSError"])
        SplunkRum.reportError(error: nsError)
    }

    func trackLegacyException() {
        let nsException = DemoErrors.nsException()
        SplunkRum.reportError(exception: nsException)
    }

    func trackLegacyEvent() {
        let testDict = NSDictionary(dictionary: ["key1": "1", "key2": "2"])
        SplunkRum.reportEvent(name: "Legacy event", attributes: testDict)
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

    class MyCustomError: NSError, @unchecked Sendable {}
    static func nsErrorSubclass() -> NSError {
        return MyCustomError(domain: "com.example.mycustomerrordomain",
                             code: 43,
                             userInfo: [NSLocalizedDescriptionKey: "This is an instance of MyCustomError."])
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
        attributes.setString("NSErrorDomain", for: "domain_set_in_attributes")
        attributes.setInt(44, for: "code_set_in_attributes")
        return attributes
    }

    static func forNSErrorSubclass() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setString("NSErrorDomain", for: "domain_set_in_attributes")
        attributes.setInt(45, for: "code_set_in_attributes")
        attributes.setString("NSError subclass", for: "what")
        return attributes
    }

    static func forNSException() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setString("NSExceptionName", for: "exceptionName")
        attributes.setInt(46, for: "code_set_in_attributes")
        attributes.setString("Sample reason", for: "reason")
        return attributes
    }
}
