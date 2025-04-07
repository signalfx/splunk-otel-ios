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


// MARK: - Type Aliases for Attribute Keys

private typealias ExceptionKeys = ErrorAttributeKeys.Exception
private typealias ServiceKeys = ErrorAttributeKeys.Service


// MARK: - ErrorEventData

struct ErrorEventData: ModuleEventData {
    private let attributes: [String: EventAttributeValue]

    init(error: TrackedError) {
    	// Core error attributes
	var attrs: [ExceptionKeys: EventAttributeValue] = [
	    .type: .string(error.typeName),
	    .message: .string(error.message)
	]

	// Stacktrace if available
	if let stacktrace = error.stacktrace {
	    attrs[.stacktrace] = .string(stacktrace.formatted)
	}

	// Service name if provided
	var serviceAttrs: [ServiceKeys: EventAttributeValue] = [:]
	if let serviceName = error.serviceName {
            serviceAttrs[.name] = .string(serviceName)
	}

	self.attributes = Dictionary(attrs)
	    .merging(Dictionary(serviceAttrs)) { $1 }
    }
}


// MARK: - Attribute Access

extension ErrorEventData {
    func getAttributes() -> [String: EventAttributeValue] {
        attributes
    }
}
