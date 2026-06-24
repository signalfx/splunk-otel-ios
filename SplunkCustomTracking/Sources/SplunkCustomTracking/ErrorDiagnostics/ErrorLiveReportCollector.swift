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

#if canImport(CrashReporter)
    import CrashReporter

    final class ErrorLiveReportImageExtractor {

        func imagesJSON(from report: PLCrashReport, matching stacktrace: Stacktrace) -> String? {
            let emittedImageNames = stacktrace.referencedImageNames

            guard !emittedImageNames.isEmpty else {
                return nil
            }

            var outputImages: [Any] = []

            for image in report.images {
                guard let image = image as? PLCrashReportBinaryImageInfo else {
                    continue
                }

                guard imageName(image.imageName, matchesAnyOf: emittedImageNames) else {
                    continue
                }

                var imageDictionary: [ErrorDiagnosticKeys: Any] = [:]
                imageDictionary[.baseAddress] = image.imageBaseAddress
                imageDictionary[.imageSize] = image.imageSize
                imageDictionary[.imagePath] = image.imageName
                imageDictionary[.imageUUID] = image.imageUUID
                outputImages.append(imageDictionary)
            }

            guard !outputImages.isEmpty else {
                return nil
            }

            return ErrorDiagnosticJSON.convertToJSONString(outputImages)
        }

        private func imageName(_ imageName: String, matchesAnyOf emittedImageNames: Set<String>) -> Bool {
            !normalizedImageNames(imageName).isDisjoint(with: emittedImageNames)
        }
    }

    final class ErrorLiveReportCollector {

        private let imageExtractor = ErrorLiveReportImageExtractor()
        private var crashReporter: PLCrashReporter?

        func configureIfNeeded() {
            guard crashReporter == nil else {
                return
            }

            #if os(tvOS)
                let signalHandlerType = PLCrashReporterSignalHandlerType.BSD
            #else
                let signalHandlerType = PLCrashReporterSignalHandlerType.mach
            #endif

            let fileManager = FileManager.default
            let crashDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SplunkCustomTracking", isDirectory: true)
            try? fileManager.createDirectory(at: crashDirectory, withIntermediateDirectories: true)

            let signalConfig = PLCrashReporterConfig(
                signalHandlerType: signalHandlerType,
                symbolicationStrategy: [],
                basePath: crashDirectory.path
            )

            crashReporter = PLCrashReporter(configuration: signalConfig)
        }

        func exceptionImages(for issue: SplunkIssue) -> String? {
            configureIfNeeded()

            guard
                let crashReporter,
                let stacktrace = issue.stacktrace
            else {
                return nil
            }

            do {
                let reportData: Data
                if let exception = issue.capturedNSException {
                    reportData = try crashReporter.generateLiveReport(with: exception)
                }
                else {
                    reportData = try crashReporter.generateLiveReport()
                }

                let report = try PLCrashReport(data: reportData)
                return imageExtractor.imagesJSON(from: report, matching: stacktrace)
            }
            catch {
                return nil
            }
        }
    }

#endif
