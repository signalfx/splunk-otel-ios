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

internal import SplunkLogger
internal import SplunkCustomTracking


final class CustomTracking: CustomTrackingModule {

    unowned let module: SplunkCustomTracking.CustomTracking

    private let internalLogger: InternalLogger


    init(for module: SplunkCustomTracking.CustomTracking) {
        self.module = module
        internalLogger = InternalLogger(configuration: .agent(category: "CustomTracking Module"))
    }


    // MARK: - Public API

    func trackCustomEvent(_ name: String, _ attributes: [String : Any]) {
        <#code#>
    }
    
    func trackError(_ message: String, _ attributes: [String : Any]) {
        <#code#>
    }
    
    func trackError(_ error: any Error, _ attributes: [String : Any]) {
        <#code#>
    }
    
    func trackError(_ ns_error: NSError, _ attributes: [String : Any]) {
        <#code#>
    }
    
    func trackException(_ exception: NSException, _ attributes: [String : Any]) {
        <#code#>
    }
}
