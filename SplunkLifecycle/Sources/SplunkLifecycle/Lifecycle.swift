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

/// The lifecycle module tracks UI object lifecycle events.
public final class Lifecycle: Sendable {

    // MARK: - Internal

    let applicationBundleName: String?
    let lifecycleEventStreamProvider: any LifecycleEventStreamProviding


    // MARK: - Public

    /// The active module configuration.
    public internal(set) nonisolated(unsafe) var configuration = LifecycleConfiguration()


    // MARK: - Initialization

    /// Module protocol conformance.
    public required convenience init() {
        self.init(
            lifecycleEventStreamProvider: DefaultLifecycleEventStreamProvider()
        )
    }

    @_spi(SplunkTesting)
    public init(
        lifecycleEventStreamProvider: any LifecycleEventStreamProviding,
        applicationBundleName: String? = nil
    ) {
        self.lifecycleEventStreamProvider = lifecycleEventStreamProvider
        self.applicationBundleName = applicationBundleName
    }


    // MARK: - Internal

    func update(configuration: LifecycleConfiguration) {
        self.configuration = configuration
    }
}
