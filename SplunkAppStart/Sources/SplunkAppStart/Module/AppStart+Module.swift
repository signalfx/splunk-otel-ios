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

import Foundation
import SplunkCommon

public struct AppStartData: ModuleEventData {}

public struct AppStartMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

extension AppStart: Module {

    // MARK: - Module types

    public typealias Configuration = AppStartConfiguration
    public typealias RemoteConfiguration = AppStartRemoteConfiguration

    public typealias EventMetadata = AppStartMetadata
    public typealias EventData = AppStartData


    // MARK: - Module methods

    public func install(with _: (any ModuleConfiguration)?, remoteConfiguration _: (any RemoteModuleConfiguration)?) {
        let install = { [self] in
            // Agent installation completes the recorder handoff later in the
            // same main-thread lifecycle sequence. Defer resolution before
            // registering listeners so an early native callback cannot win
            // the race with the hybrid snapshot.
            deferInitialLifecycleResolution()
            startDetection()
        }

        if Thread.isMainThread {
            install()
        }
        else {
            DispatchQueue.main.sync(execute: install)
        }
    }


    // MARK: - Type transparency helpers

    public func deleteData(for _: any ModuleEventMetadata) {}
    public func onPublish(data _: @escaping (AppStartMetadata, AppStartData) -> Void) {}
}
