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

        func imagesJSON(from report: PLCrashReport) -> String? {
            var usedImageNames: [String] = []

            for thread in report.threads {
                guard let thread = thread as? PLCrashReportThreadInfo else {
                    continue
                }

                collectUsedImageNames(from: thread.stackFrames, report: report, into: &usedImageNames)
            }

            guard !usedImageNames.isEmpty else {
                return nil
            }

            var outputImages: [Any] = []

            for image in report.images {
                guard let image = image as? PLCrashReportBinaryImageInfo else {
                    continue
                }

                guard usedImageNames.contains(image.imageName) else {
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

        private func collectUsedImageNames(
            from frames: [Any],
            report: PLCrashReport,
            into usedImageNames: inout [String]
        ) {
            guard let frames = frames as? [PLCrashReportStackFrameInfo] else {
                return
            }

            for stackFrame in frames {
                let instructionPointer = stackFrame.instructionPointer
                let imageInfo = report.image(forAddress: instructionPointer)
                if let imageName = imageInfo?.imageName {
                    usedImageNames.append(imageName)
                }
            }
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

            guard let crashReporter else {
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
                return imageExtractor.imagesJSON(from: report)
            }
            catch {
                return nil
            }
        }
    }

#endif
