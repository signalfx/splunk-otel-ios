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

struct DemoErrors {

    // MARK: - Inline types

    class MyCustomError: NSError, @unchecked Sendable {}


    // MARK: - Errors

    /// String error (no stack trace needed).
    static func stringError() -> String {
        "This is a string representing an error message"
    }

    /// Swift Error with stack trace.
    static func swiftError() -> Error {
        struct SampleError: Error, LocalizedError {
            var errorDescription: String? {
                "This is a Swift Error"
            }
        }

        return SampleError()
    }

    /// NSError with stack trace.
    static func nsError() -> NSError {
        NSError(
            domain: "com.example.error",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "This is an NSError"]
        )
    }

    static func nsErrorSubclass() -> NSError {
        MyCustomError(
            domain: "com.example.mycustomerrordomain",
            code: 43,
            userInfo: [NSLocalizedDescriptionKey: "This is an instance of MyCustomError."]
        )
    }

    /// NSException with stack trace (from callStackSymbols).
    static func nsException() -> NSException {
        // Use the Objective-C helper to trigger and catch an NSException
        let exception = ObjCExceptionHelper.performBlockAndCatchException {
            // Trigger an NSException by calling an unrecognized selector
            NSObject().perform(Selector(("nonExistentMethod")))
        }

        // Ensure the exception was captured
        guard let exception else {
            fatalError("Failed to trigger NSException")
        }

        return exception
    }
}
