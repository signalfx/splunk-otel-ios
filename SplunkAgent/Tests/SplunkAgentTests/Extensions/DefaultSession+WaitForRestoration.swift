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


@testable import SplunkAgent

extension DefaultSession {

    /// Waits until the restoring of the saved held starts has finished, and the work queued on the
    /// access queue so far has run, including the releases that waited for the restoring.
    ///
    /// The saved starts are read on the store's queue, and the read's completion queues the finishing
    /// on the access queue. Both queues are serial, so waiting for the store's queue and then reading
    /// the current session id, which waits for the access queue, returns after the finishing. A check
    /// after this wait does not depend on timing.
    ///
    /// Must not be called while a storage call of the store is blocked.
    func waitForHeldStartRestoration() {
        heldSessionStarts.waitForRequestedSaves()
        _ = currentSessionId
    }
}
