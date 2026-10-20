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

internal import CiscoSessionReplay
import Foundation

/// The interaction capture object implements public API for interaction category controls.
final class SessionReplayInteractionCapture: SessionReplayModuleInteractionCapture {

    // MARK: - Internal

    var module: CiscoSessionReplay.SessionReplay? {
        get {
            lock.withLock {
                linkedModule
            }
        }
        set {
            lock.withLock {
                let sourceCapture = currentCapture
                linkedModule = newValue

                let targetCapture = currentCapture

                guard sourceCapture !== targetCapture else {
                    return
                }

                // Module preferences are converted before relinking, so preserve any newer capture changes.
                targetCapture.isKeyboardEnabled = sourceCapture.isKeyboardEnabled
                targetCapture.isTouchEnabled = sourceCapture.isTouchEnabled
                targetCapture.isGestureEnabled = sourceCapture.isGestureEnabled
                targetCapture.isFocusEnabled = sourceCapture.isFocusEnabled
                targetCapture.isRageTapEnabled = sourceCapture.isRageTapEnabled
            }
        }
    }


    // MARK: - Private

    private weak var linkedModule: CiscoSessionReplay.SessionReplay?

    private let detachedCapture = CiscoSessionReplay.InteractionCapture()
    private let lock = NSLock()

    private var currentCapture: CiscoSessionReplay.InteractionCapture {
        linkedModule?.preferences.interactionCapture ?? detachedCapture
    }


    // MARK: - Categories

    var isKeyboardEnabled: Bool {
        get {
            lock.withLock {
                currentCapture.isKeyboardEnabled
            }
        }
        set {
            lock.withLock {
                currentCapture.isKeyboardEnabled = newValue
            }
        }
    }

    var isTouchEnabled: Bool {
        get {
            lock.withLock {
                currentCapture.isTouchEnabled
            }
        }
        set {
            lock.withLock {
                currentCapture.isTouchEnabled = newValue
            }
        }
    }

    var isGestureEnabled: Bool {
        get {
            lock.withLock {
                currentCapture.isGestureEnabled
            }
        }
        set {
            lock.withLock {
                currentCapture.isGestureEnabled = newValue
            }
        }
    }

    var isFocusEnabled: Bool {
        get {
            lock.withLock {
                currentCapture.isFocusEnabled
            }
        }
        set {
            lock.withLock {
                currentCapture.isFocusEnabled = newValue
            }
        }
    }

    var isRageTapEnabled: Bool {
        get {
            lock.withLock {
                currentCapture.isRageTapEnabled
            }
        }
        set {
            lock.withLock {
                currentCapture.isRageTapEnabled = newValue
            }
        }
    }


    // MARK: - Initialization

    init(for module: CiscoSessionReplay.SessionReplay? = nil) {
        linkedModule = module
    }


    // MARK: - Bulk updates

    func enableAll() {
        lock.withLock {
            currentCapture.enableAll()
        }
    }

    func disableAll() {
        lock.withLock {
            currentCapture.disableAll()
        }
    }
}
