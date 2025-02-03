//
/*
Copyright 2024 Splunk Inc.

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

@testable import SplunkAgent
import CiscoSessionReplay

final class SessionReplayTestBuilder {

    // MARK: - Basic builds

    public static func buildDefault() -> SplunkAgent.SessionReplay {
        // Build Session Replay proxy with actual Session Replay module
        let module = CiscoSessionReplay.SessionReplay.instance
        let moduleProxy = SessionReplay(for: module)

        return moduleProxy
    }


    // MARK: - Non-operational builds

    public static func buildNonOperational() -> SessionReplayNonOperational {
        let moduleProxy = SessionReplayNonOperational()

        return moduleProxy
    }
}
