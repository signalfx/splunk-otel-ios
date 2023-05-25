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

struct TestsView<InnerView>: View where InnerView: View {
    var status: TestStatus
    var inner: InnerView
    
    var body: some View {
        VStack {
            inner
                .onAppear {
                    globalState.clear()
                }
            Spacer()
            Text(self.status.description)
                .background(labelColor())
                .accessibilityIdentifier("testResult")
        }
    }
    
    func labelColor() -> Color {
        switch status {
            case .running: return .yellow
            case .failure: return .red
            case .success: return .green
            default: return .white
        }
    }
}

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

var testsTracker = TestsTracker()

typealias TestFunction = (_ fail: @escaping () -> Void) -> Void

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
        
        SplunkRum.setGlobalAttributes(["testname":self.name])
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

class DataTaskWithCompletionHandlerTest: TestCase {
    init() {
        super.init(name: "URLSession.dataTaskWithCompletionHandler")
    }
    
    override func execute() {
        let url = URL(string: receiverEndpoint("/"))!
            
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data {
                if String(decoding: data, as: UTF8.self) != "hello" {
                    self.fail()
                }
            } else {
                self.fail()
            }
        }
        
        task.resume()
    }
    
    override func verify(_ span: TestZipkinSpan) {
        if !matchesTest(span) {
            return
        }

        if span.name != "HTTP GET" {
            return
        }
                
        if !validNetworkSpan(span: span) {
            print("failing because not valid network span")
            return self.fail()
        }
    }
}

class DataTaskTest: TestCase {
    init() {
        super.init(name: "URLSession.dataTask")
    }
    
    override func execute() {
        let url = URL(string: receiverEndpoint("/"))!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if String(decoding: data, as: UTF8.self) != "hello" {
                    self.fail()
                }
            } else {
                self.fail()
            }
        }
        task.resume()
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

class UploadTaskTest: TestCase {
    init() {
        super.init(name: "URLSession.uploadTask")
    }
    
    override func execute() {
        let url = URL(string: receiverEndpoint("/upload"))!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let uploadData = Data("foobar".utf8)
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let data = data {
                if String(decoding: data, as: UTF8.self) != "foobar" {
                    self.fail()
                }
            } else {
                self.fail()
            }
        }
        task.resume()
    }
    
    override func verify(_ span: TestZipkinSpan) {
        if !matchesTest(span) {
            return
        }
        
        if span.name != "HTTP POST" {
            return
        }
    }
}

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
        TestsView(status: tests.combinedStatus, inner: VStack {
            ForEach(tests.testCases.keys.sorted(), id: \.self) { test in
                TestLabel(text: test, status: tests.testCases[test] ?? .not_running)
            }
        })
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
                DataTaskTest(),
                DataTaskWithCompletionHandlerTest(),
                UploadTaskTest()
            ]
            
            for test in tests {
                test.run()
            }
        }
    }
}
