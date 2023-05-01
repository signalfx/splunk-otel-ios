import SwiftUI

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
    case not_running, running, failure, success
    
    var description: String {
        switch self {
            case .running: return "running"
            case .failure: return "failure"
            case .success: return "success"
            default: return "waiting"
        }
    }
}

struct TestLabel: View {
    @State var text = ""
    @Binding var status: TestStatus
    
    var body: some View {
        HStack {
            Text(self.text)
            Text(self.status.description)
        }
    }
}

struct TestsView<InnerView>: View where InnerView: View {
    @Binding var status: TestStatus
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

struct URLSessionTestsView: View {
    @State var status: TestStatus = .running
    @State var dataTaskStatus: TestStatus = .not_running
    
    var body: some View {
        TestsView(status: $status, inner: VStack {
            TestLabel(text: "dataTask", status: $dataTaskStatus)
        })
        .onAppear {
            self.testDataTask()
        }
    }
    
    func testDataTask() {
        self.dataTaskStatus = .running
        let url = URL(string: "http://127.0.0.1:8989")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                // Sanity check we did not change
                if String(decoding: data, as: UTF8.self) != "hello" {
                    self.fail(&self.dataTaskStatus)
                }
            } else {
                self.fail(&self.dataTaskStatus)
            }
        }
        
        task.resume()
        
        globalState.onSpan { span in
            if span.name != "HTTP GET" {
                return
            }
            
            if span.tags["http.url"] != "http://127.0.0.1:8989" {
                self.fail(&self.dataTaskStatus)
                return
            }
            
            if span.tags["http.status_code"] != "200" {
                self.fail(&self.dataTaskStatus)
                return
            }
            
            self.dataTaskStatus = .success
            self.maybeSucceed()
        }
    }
    
    func fail(_ detail: inout TestStatus) {
        detail = .failure
        self.status = .failure
    }
    
    func maybeSucceed() {
        for status in [self.dataTaskStatus] {
            if status != .success {
                return
            }
        }
        
        self.status = .success
    }
}

struct NetworkingTestsView: View {
    @ObservedObject var state: PublishedState = globalState
    
    var body: some View {
        NavigationView {
            NavigationLink(destination: URLSessionTestsView()) {
                Text("URLSession tests")
                    .accessibilityIdentifier("urlSessionTests")
            }
        }
    }
}

struct ContentView: View {

    var body: some View {
        NavigationView {
            NavigationLink(destination: NetworkingTestsView()) {
                Text("Network instrumentation tests")
                    .accessibilityIdentifier("networkInstrTests")
            }
        }
    }
}
