//
/*
Copyright 2024 Splunk Inc.

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

/// A standard job can be used across the agent to simplify access to recurring jobs.
class RepeatingJob: AgentRepeatingJob {

    // MARK: - Private

    private var timer: Timer?
    private(set) var executionBlock: () -> Void


    // MARK: - Public

    private(set) var name: String?
    private(set) var interval: TimeInterval
    private(set) var tolerance: TimeInterval = 0.1

    var suspended: Bool {
        timer == nil
    }


    // MARK: - Initialization

    required init(named name: String? = nil, interval: TimeInterval, block: @escaping () -> Void) {
        self.name = name
        self.interval = interval

        // We preserve block for further use in our timer
        executionBlock = block
    }

    deinit {
        invalidateTimer()
    }


    // MARK: - Job management

    @discardableResult
    func resume() -> Self {
        guard timer == nil else {
            return self
        }

        // We create the corresponding timer
        timer = createTimer()

        return self
    }

    @discardableResult
    func suspend() -> Self {
        guard timer != nil else {
            return self
        }

        // Due to the nature of the Timer API,
        // the current timer needs to be invalidated.
        invalidateTimer()

        return self
    }


    // MARK: - Private methods

    private func createTimer() -> Timer {
        let newTimer = Timer(timeInterval: interval, repeats: true) { [unowned self] _ in
            self.executionBlock()
        }
        newTimer.tolerance = tolerance

        // We need a timer that won't wait on UI events
        RunLoop.current.add(newTimer, forMode: .common)

        return newTimer
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
}
