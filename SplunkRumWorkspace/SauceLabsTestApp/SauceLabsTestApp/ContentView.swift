import SwiftUI
import SplunkOtel

struct TestButton: View {
    @State var text = ""
    @State var action: () -> Void
    
    init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    var body: some View {
        Button(self.text, action: self.action)
    }
}

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
    @Published var testCases: [String:TestStatus] = [:]
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
                .background(labelColor())
                .accessibilityIdentifier("testResult")
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
                Text("Results")
                    .accessibilityIdentifier("results")
            }
        }
        .onAppear {
            let tests = [
                AppStartTest(),
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
