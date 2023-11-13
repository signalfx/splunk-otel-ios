//
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

class AppStartTest: TestCase {
    init() {
        super.init(name: "appStart")
    }

    override func verify(_ span: TestZipkinSpan) {
        if span.name != "AppStart" {
            return
        }

        if span.tags["component"] != "appstart" {
            return self.fail()
        }

        if span.tags["app"] != "SauceLabsTestApp" {
            return self.fail()
        }
    }
}

class SplunkRumInitializeTest: TestCase {
    init() {
        super.init(name: "initialize")
    }

    override func verify(_ span: TestZipkinSpan) {
        if span.name != "SplunkRum.initialize" {
            return
        }

        if span.tags["component"] != "appstart" {
            return self.fail()
        }

        if span.tags["app"] != "SauceLabsTestApp" {
            return self.fail()
        }
    }
}
