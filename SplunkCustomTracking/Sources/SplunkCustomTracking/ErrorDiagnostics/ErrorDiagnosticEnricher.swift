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
import SplunkCommon

struct ErrorDiagnostics {
    let processPath: String?
    let exceptionThreadsJSON: String?
    let exceptionImagesJSON: String?

    static let empty = Self(processPath: nil, exceptionThreadsJSON: nil, exceptionImagesJSON: nil)
}

final class ErrorDiagnosticEnricher {

    private let diagnosticsQueue = DispatchQueue(
        label: PackageIdentifier.default(named: "ErrorDiagnosticEnricher"),
        qos: .utility
    )

    private let processPath: String?
    private let imageMetadataResolver: LoadedImageMetadataResolving
    private let imageMetadataFormatter = LoadedImageMetadataFormatter()

    private var includeBinaryImagesOnErrors = true

    init(
        imageMetadataResolver: LoadedImageMetadataResolving = LoadedImageMetadataCache(),
        processPathProvider: @escaping () -> String? = { Bundle.main.executableURL?.path }
    ) {
        processPath = processPathProvider()
        self.imageMetadataResolver = imageMetadataResolver
    }

    func configure(includeBinaryImagesOnErrors: Bool) {
        diagnosticsQueue.sync {
            self.includeBinaryImagesOnErrors = includeBinaryImagesOnErrors
        }
    }

    func diagnostics(for issue: SplunkIssue) -> ErrorDiagnostics {
        guard let stacktrace = issue.stacktrace else {
            return .empty
        }

        let includeBinaryImages = diagnosticsQueue.sync {
            includeBinaryImagesOnErrors
        }

        let imageNameResolver: StackFrameImageNameResolver?
        if includeBinaryImages {
            imageNameResolver = { [imageMetadataResolver] instructionPointer, parsedImageName in
                imageMetadataResolver.image(containing: instructionPointer)?.imagePath ?? parsedImageName
            }
        }
        else {
            imageNameResolver = nil
        }

        let imagesJSON: String?
        if includeBinaryImages {
            let images = imageMetadataResolver.images(containing: stacktrace.symbolicationInstructionPointers)
            imagesJSON = imageMetadataFormatter.imagesJSON(from: images)
        }
        else {
            imagesJSON = nil
        }

        return ErrorDiagnostics(
            processPath: processPath,
            exceptionThreadsJSON: stacktrace.threadList(resolvingImageNamesWith: imageNameResolver),
            exceptionImagesJSON: imagesJSON
        )
    }
}

extension ErrorDiagnostics {
    func apply(to attributes: inout [String: EventAttributeValue]) {
        if let processPath {
            attributes[ErrorAttributeKeys.Crash.processPath.rawValue] = .string(processPath)
        }

        if let exceptionThreadsJSON {
            attributes[ErrorAttributeKeys.Exception.threads.rawValue] = .string(exceptionThreadsJSON)
        }

        if let exceptionImagesJSON {
            attributes[ErrorAttributeKeys.Exception.images.rawValue] = .string(exceptionImagesJSON)
        }
    }
}
