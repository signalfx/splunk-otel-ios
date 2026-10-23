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
import SplunkCommon

/// Detects foreground main-run-loop stalls and reports recovered app-hang spans.
public final class AppHangMonitor {

    // MARK: - Public State

    /// Indicates whether monitoring is enabled by configuration.
    public var isEnabled: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedIsEnabled
    }

    /// The configured main-run-loop busy threshold in milliseconds.
    public var thresholdMilliseconds: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedThresholdMilliseconds
    }

    /// Indicates whether monitoring is currently paused.
    public var isPaused: Bool {
        detector.isPaused
    }


    // MARK: - Private Properties

    private let detector = MainRunLoopHangDetector()
    private let stateLock = NSLock()
    private var storedIsEnabled = false
    private var storedThresholdMilliseconds = 250
    private var storedInteractionAssociationEnabled = true


    // MARK: - Public Methods

    /// Creates an app hang monitor.
    public init() {}

    /// Installs the monitor using module configuration.
    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration: (any RemoteModuleConfiguration)?
    ) {
        let localConfiguration = configuration as? AppHangMonitorConfiguration ?? AppHangMonitorConfiguration()
        let remoteConfiguration = remoteConfiguration as? AppHangMonitorRemoteConfiguration

        let effectiveIsEnabled = localConfiguration.isEnabled && (remoteConfiguration?.enabled ?? true)
        let effectiveThreshold = max(1, localConfiguration.thresholdMilliseconds)

        stateLock.lock()
        storedIsEnabled = effectiveIsEnabled
        storedThresholdMilliseconds = effectiveThreshold
        storedInteractionAssociationEnabled = localConfiguration.interactionAssociationEnabled
        stateLock.unlock()

        guard effectiveIsEnabled else {
            detector.stop()
            return
        }

        detector.configure(
            thresholdMilliseconds: effectiveThreshold,
            interactionAssociationEnabled: localConfiguration.interactionAssociationEnabled,
            interactionAssociationWindowMilliseconds: max(0, localConfiguration.interactionAssociationWindowMilliseconds)
        )
        detector.start()
    }

    /// Pauses hang detection until ``resume()`` is called.
    public func pause() {
        guard isEnabled else {
            return
        }

        detector.pause()
    }

    /// Resumes hang detection after a call to ``pause()``.
    public func resume() {
        guard isEnabled else {
            return
        }

        detector.resume()
    }

    /// Records an interaction timestamp for optional hang context.
    @_spi(SplunkInternal)
    public func recordInteraction(at timestamp: Date, type: String) {
        stateLock.lock()
        let shouldRecord = storedIsEnabled && storedInteractionAssociationEnabled
        stateLock.unlock()

        guard shouldRecord else {
            return
        }

        detector.recordInteraction(at: timestamp, type: type)
    }
}
