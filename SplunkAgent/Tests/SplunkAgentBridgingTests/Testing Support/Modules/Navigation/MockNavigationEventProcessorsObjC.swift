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
import SplunkAgentObjC

// Mock NavigationEventProcessorObjC implementations used by
// SplunkAgentBridgingTests to exercise the adapter/conversion layer
// between SplunkAgentObjC types and internal SplunkNavigation types.
//
// Each mock isolates a single behavior of the bridging path:
//
//  - PassthroughProcessorObjC:  returns the event unchanged
//  - AttributeProcessorObjC:   attaches caller-supplied attributes
//  - SuppressingProcessorObjC:  returns nil to suppress the event


// MARK: - Passthrough

/// Returns the event with its original name and no attributes.
final class PassthroughProcessorObjC: NSObject, NavigationEventProcessorObjC {
    func onViewController(typeName: String, controllerIdentity _: String) -> NavigationEventObjC? {
        NavigationEventObjC(name: typeName, attributes: nil)
    }
}


// MARK: - Attribute injection

/// Returns the event with a fixed set of attributes supplied at init time.
/// Used to test that NSDictionary attributes are correctly forwarded (or
/// filtered, in the case of non-String keys) through the adapter.
final class AttributeProcessorObjC: NSObject, NavigationEventProcessorObjC {
    let attributes: NSDictionary?

    init(attributes: NSDictionary?) {
        self.attributes = attributes
    }

    func onViewController(typeName: String, controllerIdentity _: String) -> NavigationEventObjC? {
        NavigationEventObjC(name: typeName, attributes: attributes)
    }
}


// MARK: - Suppression

/// Always returns nil, simulating a processor that suppresses every event.
final class SuppressingProcessorObjC: NSObject, NavigationEventProcessorObjC {
    func onViewController(typeName _: String, controllerIdentity _: String) -> NavigationEventObjC? {
        nil
    }
}
