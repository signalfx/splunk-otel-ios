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
import Alamofire

class AlamofireRequestTest: TestCase {
    init() {
        super.init(name: "Alamofire.request")
    }

    override func execute() {
        AF.request(receiverEndpoint("/")).response { response in
            if response.error != nil {
                return self.fail()
            }

            if let data = response.data {
                if String(decoding: data, as: UTF8.self) != "hello" {
                    return self.fail()
                }
            } else {
                self.fail()
            }
        }
    }

    override func verify(_ span: TestZipkinSpan) {
        if !matchesTest(span) {
            return
        }

        if span.name != "HTTP GET" {
            return
        }

        if !validNetworkSpan(span: span) {
            return self.fail()
        }
    }
}
