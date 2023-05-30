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

import SwiftUI
import SplunkOtel

enum TestStatus: CustomStringConvertible {
    case not_running, running, failure, timeout, success

    var description: String {
        switch self {
        case .running: return "running"
        case .failure: return "failure"
        case .success: return "success"
        case .timeout: return "timeout"
        default: return "not yet running"
        }
    }
}

struct TestLabel: View {
    var text = ""
    var status: TestStatus

    var body: some View {
        HStack {
            Text(self.text).frame(maxWidth: .infinity, alignment: .leading).font(.system(size: 12))
            Text(self.status.description).font(.system(size: 12))
        }
        .padding(4.0)
    }
}

var testsTracker = TestsTracker()

typealias TestFunction = (_ fail: @escaping () -> Void) -> Void

class TestsTracker: ObservableObject {
    @Published var testCases: [String: TestStatus] = [:]
    @Published var combinedStatus: TestStatus = .running

    func register(test: TestCase) {
        self.testCases[test.name] = test.status
    }

    func update(test: TestCase) {
        self.testCases[test.name] = test.status

        if combinedStatus == .running {
            if test.status == .failure || test.status == .timeout {
                combinedStatus = .failure
                return
            }

            if testCases.values.allSatisfy({ $0 == .success }) {
                combinedStatus = .success
            }
        }
    }
}

struct TestResultsView: View {
    @ObservedObject private var tests = testsTracker

    var body: some View {
        VStack {
            VStack {
                ForEach(tests.testCases.keys.sorted(), id: \.self) { test in
                    TestLabel(text: test, status: tests.testCases[test] ?? .not_running)
                }
            }
            Spacer()
            Text(self.tests.combinedStatus.description)
                .accessibility(identifier: "test_result")
                .background(labelColor())
        }.onAppear {
            ViewControllerShowTest().run()
        }
    }

    func labelColor() -> Color {
        switch tests.combinedStatus {
        case .running: return .yellow
        case .failure: return .red
        case .success: return .green
        default: return .white
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationView {
            NavigationLink(destination: TestResultsView()) {
                Text("results")
                    .accessibility(identifier: "results")
            }
        }
        .onAppear {
            let tests = [
                AppStartTest(),
                AlamofireRequestTest(),
                SplunkRumInitializeTest(),
                CustomSpanTest(),
                DataTaskTest(),
                DataTaskWithCompletionHandlerTest(),
                DownloadTaskTest(),
                UploadTaskTest()
            ]

            for test in tests {
                test.run()
            }
        }
    }
}
