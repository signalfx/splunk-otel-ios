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

/// Marks URL requests that are owned by the SDK and must not be captured by network instrumentation.
package enum InternalNetworkRequestMarker {

    // MARK: - Constants

    private static let propertyKey = "com.splunk.rum.internal-network-request"


    // MARK: - Request marking

    /// Returns a copy of the request marked as SDK-internal.
    ///
    /// The marker is stored as a local `URLProtocol` property, so it is available to in-process
    /// instrumentation but is not serialized as an HTTP header or sent over the wire.
    package static func mark(_ request: URLRequest) -> URLRequest {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request
        }

        URLProtocol.setProperty(true, forKey: propertyKey, in: mutableRequest)
        return mutableRequest as URLRequest
    }

    /// Returns whether the request was marked as SDK-internal.
    package static func isMarked(_ request: URLRequest) -> Bool {
        URLProtocol.property(forKey: propertyKey, in: request) as? Bool == true
    }
}
