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

import XCTest

@testable import SplunkCustomTracking

@_cdecl("splunk_custom_tracking_image_lookup_anchor")
private func splunkCustomTrackingImageLookupAnchor() {}

final class LoadedImageMetadataResolverTests: XCTestCase {

    // MARK: - Image resolution

    func testImageContainingKnownInstructionPointerResolvesImageMetadata() throws {
        let instructionPointer = anchorInstructionPointer()

        let image = try XCTUnwrap(LoadedImageMetadataCache().image(containing: instructionPointer))

        XCTAssertGreaterThan(image.baseAddress, 0)
        XCTAssertGreaterThan(image.imageSize, 0)
        XCTAssertFalse(image.imagePath.isEmpty)
        XCTAssertLessThanOrEqual(image.baseAddress, instructionPointer)
    }

    func testImageUUIDUsesCrashReportHexFormat() throws {
        let instructionPointer = anchorInstructionPointer()

        let image = try XCTUnwrap(LoadedImageMetadataCache().image(containing: instructionPointer))
        let imageUUID = try XCTUnwrap(image.imageUUID)

        XCTAssertEqual(imageUUID.count, 32)
        let allowedCharacters = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(imageUUID.unicodeScalars.allSatisfy { allowedCharacters.contains($0) })
    }

    func testImagesContainingDeduplicatesByBaseAddress() {
        let instructionPointer = anchorInstructionPointer()

        let images = LoadedImageMetadataCache().images(containing: [instructionPointer, instructionPointer])

        XCTAssertEqual(images.count, 1)
    }

    func testInvalidInstructionPointerIsIgnored() {
        let imageCache = LoadedImageMetadataCache()

        XCTAssertNil(imageCache.image(containing: 0))
        XCTAssertTrue(imageCache.images(containing: [0]).isEmpty)
    }

    // MARK: - Diagnostics

    func testDiagnosticsWhenImagesAreDisabledDoesNotResolveImages() {
        struct FileError: Error {}

        let imageResolver = CountingImageResolver()
        let enricher = ErrorDiagnosticEnricher(
            imageMetadataResolver: imageResolver,
            processPathProvider: { "/TestApp" }
        )
        enricher.configure(includeBinaryImagesOnErrors: false)

        let diagnostics = enricher.diagnostics(for: SplunkIssue(from: FileError()))

        XCTAssertEqual(imageResolver.lookupCount, 0)
        XCTAssertEqual(diagnostics.processPath, "/TestApp")
        XCTAssertNotNil(diagnostics.exceptionThreadsJSON)
        XCTAssertNil(diagnostics.exceptionImagesJSON)
    }

    func testDiagnosticsCachesProcessPathProviderAtInitialization() {
        struct FileError: Error {}

        var processPathLookupCount = 0
        let enricher = ErrorDiagnosticEnricher(
            imageMetadataResolver: CountingImageResolver(),
            processPathProvider: {
                processPathLookupCount += 1
                return "/TestApp"
            }
        )
        enricher.configure(includeBinaryImagesOnErrors: false)

        let firstDiagnostics = enricher.diagnostics(for: SplunkIssue(from: FileError()))
        let secondDiagnostics = enricher.diagnostics(for: SplunkIssue(from: FileError()))

        XCTAssertEqual(firstDiagnostics.processPath, "/TestApp")
        XCTAssertEqual(secondDiagnostics.processPath, "/TestApp")
        XCTAssertEqual(processPathLookupCount, 1)
    }

    func testDiagnosticsReusesResolvedImagesForThreadsAndImages() throws {
        var issue = SplunkIssue(from: "message")
        issue.stacktrace = Stacktrace(frames: [
            "0   AgentTestApp                        0x0000000100000100 first() + 4",
            "1   AgentTestApp                        0x0000000100000200 repeated() + 8",
            "2   AgentTestApp                        0x0000000100000200 repeated() + 8"
        ])

        let expectedImagePath = "/private/Frameworks/Test.framework/Test"
        let imageResolver = StaticImageResolver(
            image: LoadedImage(
                baseAddress: 0x1_0000_0000,
                imageSize: 0x1000,
                imagePath: expectedImagePath,
                imageUUID: "0123456789abcdef0123456789abcdef"
            )
        )
        let enricher = ErrorDiagnosticEnricher(
            imageMetadataResolver: imageResolver,
            processPathProvider: { "/TestApp" }
        )

        let diagnostics = enricher.diagnostics(for: issue)
        let threadsJSON = try XCTUnwrap(diagnostics.exceptionThreadsJSON)
        let imagesJSON = try XCTUnwrap(diagnostics.exceptionImagesJSON)

        let threads = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(threadsJSON.utf8)) as? [[String: Any]])
        let images = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(imagesJSON.utf8)) as? [[String: Any]])
        let stackFrames = try XCTUnwrap(threads[0]["stackFrames"] as? [[String: Any]])

        XCTAssertEqual(imageResolver.lookupCount, 2)
        XCTAssertEqual(stackFrames.compactMap { $0["imageName"] as? String }, [expectedImagePath, expectedImagePath, expectedImagePath])
        XCTAssertEqual(images.count, 1)
        XCTAssertEqual(images[0]["imagePath"] as? String, expectedImagePath)
    }

    func testDiagnosticsWhenImagesAreEnabledEmitsResolvedImagePath() throws {
        struct FileError: Error {}

        let expectedImagePath = "/private/Frameworks/Test.framework/Test"
        let imageResolver = StaticImageResolver(
            image: LoadedImage(
                baseAddress: 0x1_0000_0000,
                imageSize: 0x1000,
                imagePath: expectedImagePath,
                imageUUID: "0123456789abcdef0123456789abcdef"
            )
        )
        let enricher = ErrorDiagnosticEnricher(
            imageMetadataResolver: imageResolver,
            processPathProvider: { "/TestApp" }
        )

        let diagnostics = enricher.diagnostics(for: SplunkIssue(from: FileError()))
        let threadsJSON = try XCTUnwrap(diagnostics.exceptionThreadsJSON)
        let imagesJSON = try XCTUnwrap(diagnostics.exceptionImagesJSON)

        let threads = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(threadsJSON.utf8)) as? [[String: Any]])
        let images = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(imagesJSON.utf8)) as? [[String: Any]])
        let stackFrames = try XCTUnwrap(threads[0]["stackFrames"] as? [[String: Any]])

        let containsResolvedImagePath = stackFrames.contains { ($0["imageName"] as? String) == expectedImagePath }
        XCTAssertTrue(containsResolvedImagePath)
        XCTAssertEqual(images.count, 1)
        XCTAssertEqual(images[0]["imagePath"] as? String, expectedImagePath)
    }

    private func anchorInstructionPointer() -> UInt64 {
        let function = splunkCustomTrackingImageLookupAnchor as @convention(c) () -> Void
        let pointer = unsafeBitCast(function, to: UnsafeRawPointer.self)

        return UInt64(UInt(bitPattern: pointer))
    }
}

private final class CountingImageResolver: LoadedImageMetadataResolving {
    private(set) var lookupCount = 0

    func image(containing _: UInt64) -> LoadedImage? {
        lookupCount += 1
        return nil
    }

    func images(containing instructionPointers: [UInt64]) -> [LoadedImage] {
        lookupCount += instructionPointers.count
        return []
    }
}

private final class StaticImageResolver: LoadedImageMetadataResolving {
    private let image: LoadedImage
    private(set) var lookupCount = 0

    init(image: LoadedImage) {
        self.image = image
    }

    func image(containing _: UInt64) -> LoadedImage? {
        lookupCount += 1
        return image
    }

    func images(containing instructionPointers: [UInt64]) -> [LoadedImage] {
        lookupCount += instructionPointers.count
        return instructionPointers.isEmpty ? [] : [image]
    }
}
