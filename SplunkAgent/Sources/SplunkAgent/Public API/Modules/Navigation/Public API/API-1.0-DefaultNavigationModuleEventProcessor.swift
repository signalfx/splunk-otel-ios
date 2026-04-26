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

/// The default processor that passes navigation events through unchanged.
///
/// This processor returns the sanitized controller type name as the screen name
/// with no additional attributes. It is used automatically when no custom
/// ``NavigationModuleEventProcessor`` is configured.
public final class DefaultNavigationModuleEventProcessor: NavigationModuleEventProcessor {

    // MARK: - Initialization

    public init() {}


    // MARK: - Processor methods

    public func onViewController(typeName: String, controllerIdentity _: String) -> NavigationModuleEvent? {
        NavigationModuleEvent(name: typeName)
    }
}
