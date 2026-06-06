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

import SplunkUICommon

/// The lifecycle module tracks UI object lifecycle events.
public final class Lifecycle: Sendable {

    // MARK: - Internal

    let lifecycleEventStreamProvider: any LifecycleEventStreamProviding
    let runtimeStateStore: LifecycleRuntimeStateStore

    var applicationBundleName: String? {
        runtimeStateStore.applicationBundleName
    }


    // MARK: - Public

    /// The active module configuration.
    public internal(set) var configuration: LifecycleConfiguration {
        get {
            runtimeStateStore.configuration
        }
        set {
            runtimeStateStore.setConfiguration(newValue)
        }
    }


    // MARK: - Initialization

    /// Module protocol conformance.
    public required convenience init() {
        self.init(
            lifecycleEventStreamProvider: DefaultLifecycleEventStreamProvider(),
            applicationBundleName: ClassNameSanitization.applicationBundleName()
        )
    }

    @_spi(SplunkTesting)
    public init(
        lifecycleEventStreamProvider: any LifecycleEventStreamProviding,
        applicationBundleName: String? = nil
    ) {
        self.lifecycleEventStreamProvider = lifecycleEventStreamProvider
        runtimeStateStore = LifecycleRuntimeStateStore(
            applicationBundleName: applicationBundleName
        )
    }


    // MARK: - Internal

    func update(configuration: LifecycleConfiguration) {
        runtimeStateStore.setConfiguration(configuration)
    }

    @_spi(SplunkInternal)
    public func setApplicationBundleName(_ applicationBundleName: String?) {
        runtimeStateStore.setApplicationBundleName(applicationBundleName)
    }
}
