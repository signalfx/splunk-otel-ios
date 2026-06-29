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
    import SplunkCommon

    final class ErrorLiveReportImageExtractor {

        func imagesJSON(from snapshot: ErrorLiveReportSnapshot, matching stacktrace: Stacktrace) -> String? {
            let emittedImageNames = stacktrace.referencedImageNames

            guard !emittedImageNames.isEmpty else {
                return nil
            }

            var outputImages: [Any] = []

            for image in snapshot.images {
                guard imageName(image.imagePath, matchesAnyOf: emittedImageNames) else {
                    continue
                }

                var imageDictionary: [ErrorDiagnosticKeys: Any] = [:]
                imageDictionary[.baseAddress] = image.imageBaseAddress
                imageDictionary[.imageSize] = image.imageSize
                imageDictionary[.imagePath] = image.imagePath

                if let imageUUID = image.imageUUID {
                    imageDictionary[.imageUUID] = imageUUID
                }

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

    struct ErrorLiveReportBinaryImage {
        let imageBaseAddress: UInt64
        let imageSize: UInt64
        let imagePath: String
        let imageUUID: String?

        func contains(instructionPointer: UInt64) -> Bool {
            guard imageSize > 0 else {
                return instructionPointer == imageBaseAddress
            }

            let end = imageBaseAddress.addingReportingOverflow(imageSize)
            guard !end.overflow else {
                return instructionPointer >= imageBaseAddress
            }

            return instructionPointer >= imageBaseAddress && instructionPointer < end.partialValue
        }
    }

    struct ErrorLiveReportSnapshot {
        let processPath: String?
        let images: [ErrorLiveReportBinaryImage]

        init(report: PLCrashReport) {
            processPath = report.hasProcessInfo ? report.processInfo.processPath : nil

            images = report.images.compactMap { image in
                guard let image = image as? PLCrashReportBinaryImageInfo else {
                    return nil
                }

                let imageUUID: String? = image.imageUUID

                return ErrorLiveReportBinaryImage(
                    imageBaseAddress: image.imageBaseAddress,
                    imageSize: image.imageSize,
                    imagePath: image.imageName,
                    imageUUID: imageUUID
                )
            }
        }

        func image(containing instructionPointer: UInt64) -> ErrorLiveReportBinaryImage? {
            images.first { image in
                image.contains(instructionPointer: instructionPointer)
            }
        }
    }

    final class ErrorLiveReportCollector {

        private let collectorQueue = DispatchQueue(
            label: PackageIdentifier.default(named: "ErrorLiveReportCollector"),
            qos: .utility
        )

        private let imageExtractor = ErrorLiveReportImageExtractor()
        private var crashReporter: PLCrashReporter?
        private var snapshot: ErrorLiveReportSnapshot?

        func prepare() {
            collectorQueue.async {
                self.refreshSnapshotIfNeeded()
            }
        }

        private func configureIfNeeded() {
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

        func diagnostics(
            for stacktrace: Stacktrace,
            includeBinaryImages: Bool,
            completion: @escaping (ErrorDiagnostics) -> Void
        ) {
            collectorQueue.async {
                self.refreshSnapshotIfNeeded()

                guard let snapshot = self.snapshot else {
                    completion(.empty)
                    return
                }

                let threadsJSON: String?
                if includeBinaryImages {
                    threadsJSON = stacktrace.threadList { instructionPointer, parsedImageName in
                        snapshot.image(containing: instructionPointer)?.imagePath ?? parsedImageName
                    }
                }
                else {
                    threadsJSON = nil
                }

                let imagesJSON = includeBinaryImages ? self.imageExtractor.imagesJSON(from: snapshot, matching: stacktrace) : nil

                completion(ErrorDiagnostics(
                    processPath: snapshot.processPath,
                    exceptionThreadsJSON: threadsJSON,
                    exceptionImagesJSON: imagesJSON
                ))
            }
        }

        private func refreshSnapshotIfNeeded() {
            guard snapshot == nil else {
                return
            }

            configureIfNeeded()

            guard let crashReporter else {
                return
            }

            do {
                let reportData = try crashReporter.generateLiveReport()
                let report = try PLCrashReport(data: reportData)
                snapshot = ErrorLiveReportSnapshot(report: report)
            }
            catch {
                snapshot = nil
            }
        }
    }

#endif
