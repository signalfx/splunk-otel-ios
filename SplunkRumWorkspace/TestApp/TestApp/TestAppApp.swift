/*
Copyright 2021 Splunk Inc.

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

import SwiftUI
// Why not "import SplunkOtel"?  Because this links as a local framework, not as a swift package.
// FIXME align the framework name and directory names with the swift package name at some point
import SplunkRum

@main
struct TestAppApp: App {
    init() {
         SplunkRum.initialize(beaconUrl: "https://rum-ingest.us0.signalfx.com/v1/rum", rumAuth: "nF2sRwMTyB-is8WpcGQ72w", options: SplunkRumOptions(allowInsecureBeacon: true, debug: true, globalAttributes: ["strKey": "Some string", "intkey": 7]))
        
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
