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

/// Defines a base Endpoint model which is used by `APIClient` to define service requests with HTTP headers
protocol Endpoint {
    associatedtype RequestHeaders: APIClientHeaders

    /// Defines service model
    static var service: Service { get }

    /// Defines request headers model
    var requestHeaders: RequestHeaders? { get }
}


// MARK: - URL constructing

extension Endpoint {

    /// Returns URL path constructed from a baseUrl and the `Service` path
    func url(with baseUrl: URL) -> URL {
        baseUrl.appendingPathComponent(Self.service.path)
    }
}
