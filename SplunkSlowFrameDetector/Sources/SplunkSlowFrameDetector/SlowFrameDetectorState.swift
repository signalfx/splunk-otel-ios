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

import os.lock

/// A thread-safe representation of the current state of the `SlowFrameDetector` module.
///
/// This class uses an internal lock to safely manage its state across concurrent contexts.
public final class SlowFrameDetectorState: @unchecked Sendable {

    // MARK: - Private Properties

    /// A private lock to synchronize access.
    private let lock = os_unfair_lock_t.allocate(capacity: 1)

    /// The actual storage for the isEnabled property.
    private var _isEnabled: Bool = false


    // MARK: - Public Properties

    /// Indicates whether the slow frame detection feature is currently enabled.
    ///
    /// Access to this property is synchronized via an internal lock.
    public internal(set) var isEnabled: Bool {
        get {
            os_unfair_lock_lock(lock)
            defer { os_unfair_lock_unlock(lock) }
            return _isEnabled
        }
        set {
            os_unfair_lock_lock(lock)
            defer { os_unfair_lock_unlock(lock) }
            _isEnabled = newValue
        }
    }


    // MARK: - Initialization

    /// Initializes a new state object.
    public init() {
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }
}
