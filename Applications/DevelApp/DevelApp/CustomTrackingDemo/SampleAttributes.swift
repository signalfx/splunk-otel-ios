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

import SplunkAgent

struct SampleAttributes {

    static func forStringError() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setString("sampleValue", for: "stringKey")

        return attributes
    }

    static func forSwiftError() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setBool(true, for: "isSwiftError")
        attributes.setInt(404, for: "errorCode")

        return attributes
    }

    static func forNSError() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setString("NSErrorDomain", for: "domain_set_in_attributes")
        attributes.setInt(44, for: "code_set_in_attributes")

        return attributes
    }

    static func forNSErrorSubclass() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setString("NSErrorDomain", for: "domain_set_in_attributes")
        attributes.setInt(45, for: "code_set_in_attributes")
        attributes.setString("NSError subclass", for: "what")

        return attributes
    }

    static func forNSException() -> MutableAttributes {
        let attributes = MutableAttributes()
        attributes.setString("NSExceptionName", for: "exceptionName")
        attributes.setInt(46, for: "code_set_in_attributes")
        attributes.setString("Sample reason", for: "reason")

        return attributes
    }
}
