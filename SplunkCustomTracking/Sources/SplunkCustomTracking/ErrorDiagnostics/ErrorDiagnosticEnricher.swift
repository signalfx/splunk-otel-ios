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

final class ErrorDiagnosticEnricher {

    private var includeBinaryImagesOnErrors = true

    #if canImport(CrashReporter)
    private lazy var liveReportCollector = ErrorLiveReportCollector()
    #endif

    func configure(includeBinaryImagesOnErrors: Bool) {
        self.includeBinaryImagesOnErrors = includeBinaryImagesOnErrors
    }

    func exceptionImagesJSON(for issue: SplunkIssue) -> String? {
        guard includeBinaryImagesOnErrors else {
            return nil
        }

        guard issue.stacktrace != nil else {
            return nil
        }

        #if canImport(CrashReporter)
        return liveReportCollector.exceptionImages(for: issue)
        #else
        return nil
        #endif
    }
}
