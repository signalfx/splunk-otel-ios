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
import XCTest

@testable import SplunkWebView

final class WebViewBridgeScriptTests: XCTestCase {

    func testScriptResourceURL_whenNoBundleCandidatesExist_returnsNil() {
        XCTAssertNil(WebViewBridgeScript.scriptResourceURL(in: []))
    }

    func testScriptResourceURL_whenPackageBundleExists_prefersItToHostResource() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let hostBundle = try makeBundle(at: temporaryDirectory.appendingPathComponent("Host.bundle"))
        let hostScriptURL = try writeScript(in: hostBundle, contents: "host script")
        let packageBundleURL = try XCTUnwrap(hostBundle.resourceURL)
            .appendingPathComponent("SplunkAgent_SplunkWebView.bundle")
        let packageBundle = try makeBundle(at: packageBundleURL)
        let packageScriptURL = try writeScript(in: packageBundle, contents: "package script")

        let actual = WebViewBridgeScript.scriptResourceURL(
            in: [hostBundle],
            frameworkBundles: [hostBundle]
        )

        XCTAssertEqual(actual, packageScriptURL)
        XCTAssertNotEqual(actual, hostScriptURL)
    }

    func testScriptResourceURL_whenPackageBundleIsMissing_doesNotUseHostResource() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let hostBundle = try makeBundle(at: temporaryDirectory.appendingPathComponent("Host.bundle"))
        _ = try writeScript(in: hostBundle, contents: "host script")

        let actual = WebViewBridgeScript.scriptResourceURL(in: [hostBundle])

        XCTAssertNil(actual)
    }

    func testScriptResourceURL_whenPackageBundleDoesNotContainScript_doesNotUseHostResource() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let hostBundle = try makeBundle(at: temporaryDirectory.appendingPathComponent("Host.bundle"))
        _ = try writeScript(in: hostBundle, contents: "host script")
        let hostResourceURL = try XCTUnwrap(hostBundle.resourceURL)
        _ = try makeBundle(at: hostResourceURL.appendingPathComponent("SplunkAgent_SplunkWebView.bundle"))

        let actual = WebViewBridgeScript.scriptResourceURL(in: [hostBundle])

        XCTAssertNil(actual)
    }

    func testScriptResourceURL_whenPackageBundleIsInSearchDirectory_findsIt() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let packageBundle = try makeBundle(
            at: temporaryDirectory.appendingPathComponent("SplunkAgent_SplunkWebView.bundle")
        )
        let expected = try writeScript(in: packageBundle, contents: "package script")

        let actual = WebViewBridgeScript.scriptResourceURL(
            in: [],
            searchDirectories: [temporaryDirectory]
        )

        XCTAssertEqual(actual, expected)
    }

    func testScriptResourceURL_whenFrameworkContainsFlatResource_findsIt() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let frameworkBundle = try makeBundle(
            at: temporaryDirectory.appendingPathComponent("SplunkWebView.framework"),
            packageType: "FMWK"
        )
        let expected = try writeScript(in: frameworkBundle, contents: "framework script")

        let actual = WebViewBridgeScript.scriptResourceURL(in: [], frameworkBundles: [frameworkBundle])

        XCTAssertEqual(actual, expected)
    }

    func testLoadScript_whenURLIsMissing_returnsNil() {
        XCTAssertNil(WebViewBridgeScript.loadScript(from: nil))
    }

    func testLoadScript_whenFileCannotBeRead_returnsNil() {
        let missingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        XCTAssertNil(WebViewBridgeScript.loadScript(from: missingURL))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeBundle(at bundleURL: URL, packageType: String = "BNDL") throws -> Bundle {
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        let info: [String: String] = [
            "CFBundleIdentifier": "com.splunk.tests.\(UUID().uuidString)",
            "CFBundlePackageType": packageType
        ]
        let infoData = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try infoData.write(to: bundleURL.appendingPathComponent("Info.plist"))
        return try XCTUnwrap(Bundle(url: bundleURL))
    }

    private func writeScript(in bundle: Bundle, contents: String) throws -> URL {
        let resourceURL = try XCTUnwrap(bundle.resourceURL)
        try FileManager.default.createDirectory(at: resourceURL, withIntermediateDirectories: true)
        let scriptURL = resourceURL.appendingPathComponent("WebViewBridgeScript.js")
        try contents.write(to: scriptURL, atomically: true, encoding: .utf8)
        return scriptURL
    }
}
