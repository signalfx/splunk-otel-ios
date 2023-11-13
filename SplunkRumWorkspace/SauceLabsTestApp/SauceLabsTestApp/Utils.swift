/*
Copyright 2023 Splunk Inc.

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

func validNetworkSpan(span: TestZipkinSpan) -> Bool {
    if span.tags["http.url"] != receiverEndpoint("/") {
        return false
    }

    if span.tags["http.method"] != "GET" {
        return false
    }

    if span.tags["http.status_code"] != "200" {
        return false
    }

    if span.tags["component"] != "http" {
        return false
    }

    return true
}
