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

import CiscoSessionReplay
import Foundation

@testable import SplunkAgent

final class SessionReplayTestBuilder {

    // MARK: - Basic builds

    static func buildDefault() -> SplunkAgent.SessionReplay {
        // Build Session Replay proxy with actual Session Replay module
        let module = CiscoSessionReplay.SessionReplay.instance
        let moduleProxy = SessionReplay(for: module)

        return moduleProxy
    }


    // MARK: - Non-operational builds

    static func buildNonOperational() -> SessionReplayNonOperational {
        let moduleProxy = SessionReplayNonOperational()

        return moduleProxy
    }


    // MARK: - Session replay data event

    static func buildDataEvent() throws -> SessionReplayDataEvent {
        let sampleVideoData = try Self.sampleVideoData()

        let sessionId = UUID().uuidString
        let scriptInstanceId = String(sessionId.prefix(upTo: sessionId.index(sessionId.startIndex, offsetBy: 16)))
        let timestamp = Date()
        let endTimestamp = Date()

        let chunkMetadata = Metadata(
            startUnixMs: Int(timestamp.timeIntervalSince1970 * 1000.0),
            endUnixMs: Int(endTimestamp.timeIntervalSince1970 * 1000.0)
        )

        let event = SessionReplayDataEvent(
            metadata: chunkMetadata,
            data: sampleVideoData,
            index: 1,
            sessionId: sessionId,
            scriptInstanceId: scriptInstanceId
        )

        return event
    }

    static func sampleVideoData() throws -> Data {
        #if SPM_TESTS
            let fileUrl = Bundle.module.url(forResource: "v", withExtension: "mp4")!

        #else
            let bundle = Bundle(for: EventsTests.self)
            let fileUrl = bundle.url(forResource: "v", withExtension: "mp4")!
        #endif

        let data = try Data(contentsOf: fileUrl)

        return data
    }
}
