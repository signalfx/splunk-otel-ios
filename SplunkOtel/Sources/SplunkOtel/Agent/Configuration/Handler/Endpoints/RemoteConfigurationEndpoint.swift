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

/// Creates Endpoint for remote configuration download
struct RemoteConfigurationEndpoint: Endpoint {

    // MARK: - Inline types

    typealias RequestHeaders = Headers

    struct Headers: APIClientHeaders {

        let appName: String
        let appType: String
        let appPlatform: String

        var headers: [String: String] {
            [
                "x-app-name": appName,
                "x-app-type": appType,
                "x-app-platform": appPlatform
            ]
        }
    }


    // MARK: - Static constants aliases

    static var service = Service(path: "eum/v1/config", httpMethod: .get)


    // MARK: - Variables

    var requestHeaders: RequestHeaders?


    // MARK: - Initialization

    init(appName: String) {
        requestHeaders = Headers(
            appName: appName,
            appType: "mrum",
            appPlatform: "ios"
        )
    }
}
