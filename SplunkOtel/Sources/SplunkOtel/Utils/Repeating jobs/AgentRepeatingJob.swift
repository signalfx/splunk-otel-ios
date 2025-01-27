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

/// Defines general simplified API for running repeated tasks in the agent.
protocol AgentRepeatingJob {

    // MARK: - Public

    /// Optional naming for job.
    var name: String? { get }

    /// The repeating interval with which the job was initialized.
    var interval: TimeInterval { get }

    /// Tolerance for internal timer execution intervals.
    var tolerance: TimeInterval { get }

    /// Identifies whether this job is currently suspended.
    var suspended: Bool { get }


    // MARK: - Initialization

    /// Initializes a job object with the specified time interval and block.
    ///
    /// - Parameters:
    ///   - named: A `String` with job identifier.
    ///   - interval: The number of seconds between firings of the job.
    ///   - block: A block to be executed when the job fires. The block takes no parameter and has no return value.
    init(named: String?, interval: TimeInterval, block: @escaping () -> Void)


    // MARK: - Job management

    /// Starts the job execution.
    ///
    /// The first execution of the specified block is fired at the earliest after the `interval`.
    ///
    /// - Returns: The actual job instance.
    @discardableResult
    func resume() -> Self

    /// Stops the job execution with immediate effect.
    ///
    /// - Returns: The actual job instance.
    @discardableResult
    func suspend() -> Self
}
