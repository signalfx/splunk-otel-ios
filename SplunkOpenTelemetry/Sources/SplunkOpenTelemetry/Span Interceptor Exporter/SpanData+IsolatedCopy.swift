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
import OpenTelemetrySdk

// MARK: - SpanData Thread Safety Extension

extension SpanData {

    /// Creates a thread-isolated copy of `SpanData` by forcing new dictionary storage.
    ///
    /// This method addresses a thread safety issue where Swift's copy-on-write (CoW)
    /// optimization can cause data races when `SpanData` is passed across thread boundaries.
    /// When a `SpanData` struct is captured in an async closure, the internal dictionary
    /// storage is shared until mutation. If the original goes out of scope while the closure
    /// is executing, reference count operations can race, causing crashes.
    ///
    /// By creating new dictionary instances for `attributes`, `events`, `links`, and `resource`,
    /// this method ensures complete isolation from the original storage.
    ///
    /// - Returns: A new `SpanData` instance with isolated dictionary storage.
    func isolatedCopy() -> SpanData {
        var copy = self

        // Force new dictionary storage for attributes
        copy = copy.settingAttributes(
            Dictionary(uniqueKeysWithValues: attributes.map { ($0.key, $0.value) })
        )

        // Events contain their own attributes dictionaries that also need isolation
        let isolatedEvents = events.map { event in
            SpanData.Event(
                name: event.name,
                timestamp: event.timestamp,
                attributes: Dictionary(uniqueKeysWithValues: event.attributes.map { ($0.key, $0.value) })
            )
        }
        copy = copy.settingEvents(isolatedEvents)

        // Links contain their own attributes dictionaries that also need isolation
        let isolatedLinks = links.map { link in
            SpanData.Link(
                context: link.context,
                attributes: Dictionary(uniqueKeysWithValues: link.attributes.map { ($0.key, $0.value) })
            )
        }
        copy = copy.settingLinks(isolatedLinks)

        // Resource contains an attributes dictionary that also needs isolation.
        //
        // Note: As of opentelemetry-swift-core 2.3.0, Resource only has `attributes`.
        // If future versions add properties like `schemaURL`, this should be updated
        // to preserve them (e.g., using a Resource initializer that accepts schemaURL).
        let isolatedResource = Resource(
            attributes: Dictionary(uniqueKeysWithValues: resource.attributes.map { ($0.key, $0.value) })
        )
        copy = copy.settingResource(isolatedResource)

        return copy
    }
}
