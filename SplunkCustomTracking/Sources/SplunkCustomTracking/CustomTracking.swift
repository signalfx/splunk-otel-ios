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
import SplunkSharedProtocols


// MARK: - CustomTracking

public final class CustomTracking {

    // MARK: - Properties

    private var config: CustomTrackingConfiguration
    private var dataConsumer: ((CustomDataEventMetadata, CustomDataEventData) -> Void)?


    // MARK: - Initialization

    public required init() {
        self.config = CustomTrackingConfiguration(enabled: true)
    }

    // MARK: - Public API

    /// Track any item that conforms to Trackable
    /// - Parameter item: The trackable item to be tracked
    public func track<T: Trackable>(_ item: T) {
        guard config.enabled else { return }
        
        let metadata = CustomDataEventMetadata(
            timestamp: item.timestamp,
            typeName: item.typeName
        )

        let eventData = CustomDataEventData(item: item)

        dataConsumer?(metadata, eventData)
    }
}
