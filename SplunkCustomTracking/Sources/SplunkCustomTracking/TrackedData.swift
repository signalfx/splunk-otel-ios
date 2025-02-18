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
import SplunkSharedProtocols

protocol TrackedDataRepresentable: PropertyList {}

public final class TrackedData {


    // MARK: - Private properties

    private var config = TrackedDataConfiguration(enabled: true)


    // MARK: - TrackedData lifecycle

    public required init() {} // see install() in Module extension for startup tasks


    // MARK: - TrackedData helper functions


    // MARK: - TrackedData Reporting

    // This is a placeholder for temporary use only. Will be replaced by
    // real data population and output.
    private func reportCustom(data: TrackedDataRepresentable) {
        print(String(describing: data))
    }
}
