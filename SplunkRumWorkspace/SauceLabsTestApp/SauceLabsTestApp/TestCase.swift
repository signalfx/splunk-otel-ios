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
import SplunkOtel

class TestCase {
    let name: String
    var status: TestStatus = .not_running
    var timeoutHandler: DispatchWorkItem?

    init(name: String) {
        self.name = name
        self.timeoutHandler = DispatchWorkItem(block: {
            self.timeout()
        })

        globalState.onSpan { span in
            self.verify(span)
            if self.status == .running {
                self.success()
            }
        }
        testsTracker.register(test: self)
    }

    func run() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: self.timeoutHandler!)
        self.status = .running
        testsTracker.update(test: self)

        SplunkRum.setGlobalAttributes(["testname": self.name])
        self.execute()
        SplunkRum.removeGlobalAttribute("testname")
    }

    func execute() {
    }

    func verify(_ span: TestZipkinSpan) {
    }

    func end(_ status: TestStatus) {
        self.timeoutHandler?.cancel()
        self.status = status
        testsTracker.update(test: self)
    }

    func fail() {
        self.end(.failure)
    }

    func timeout() {
        self.end(.timeout)
    }

    func success() {
        self.end(.success)
    }

    func matchesTest(_ span: TestZipkinSpan) -> Bool {
        return span.tags["testname"] == self.name
    }
}
