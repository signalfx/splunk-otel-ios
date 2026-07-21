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

/// Scheduling mechanics for persisted uploads that do not have a matching URLSession task.
///
/// The state this extension uses is `internal` because Swift requires cross-file extension members
/// to have module visibility. All access remains serialized by `stalledUploadCheckLock`.
extension OTLPBackgroundHTTPBaseExporter {
    /// Schedules a coalesced scan after an active file could not be assigned a URLSession task.
    ///
    /// The file is already durable, so callers can report success without creating another copy in
    /// the in-memory retry queue. If a scan is already pending, it will cover the newly persisted file.
    func scheduleStalledUploadRecovery() {
        startStalledUploadCheck(replacingExisting: false)
    }

    func startStalledUploadCheck(replacingExisting: Bool = false) {
        guard endpoint != nil else {
            return
        }

        stalledUploadCheckLock.lock()
        if !replacingExisting, checkStalledTask != nil {
            stalledUploadCheckLock.unlock()
            return
        }

        let previousTask = checkStalledTask
        stalledUploadCheckGeneration &+= 1
        let generation = stalledUploadCheckGeneration
        let delay = stalledUploadCheckDelayNanoseconds

        // Wait 5-8s to clean caches content from abandoned or stalled files.
        let task = Task.detached(priority: .utility) { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            }
            catch {
                return
            }

            guard let self else {
                return
            }

            httpClient.getAllSessionsTasks { [weak self] tasks in
                guard let self, finishStalledUploadCheck(generation: generation) else {
                    return
                }

                checkStalledUploadsOperation(tasks: tasks)
            }
        }
        checkStalledTask = task
        stalledUploadCheckLock.unlock()

        previousTask?.cancel()
    }

    func finishStalledUploadCheck(generation: UInt64) -> Bool {
        stalledUploadCheckLock.lock()
        defer { stalledUploadCheckLock.unlock() }

        guard stalledUploadCheckGeneration == generation else {
            return false
        }

        checkStalledTask = nil
        return true
    }

    func cancelStalledUploadCheck() {
        stalledUploadCheckLock.lock()
        stalledUploadCheckGeneration &+= 1
        let task = checkStalledTask
        checkStalledTask = nil
        stalledUploadCheckLock.unlock()

        task?.cancel()
    }
}
