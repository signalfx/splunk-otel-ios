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

class DataTaskWithCompletionHandlerTest: TestCase {
    init() {
        super.init(name: "URLSession.dataTaskWithCompletionHandler")
    }

    override func execute() {
        let url = URL(string: receiverEndpoint("/"))!

        let task = URLSession.shared.dataTask(with: url) { (data, _, error) in
            if error != nil {
                return self.fail()
            }
            if let data = data {
                if String(decoding: data, as: UTF8.self) != "hello" {
                    return self.fail()
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

class DataTaskTest: TestCase {
    init() {
        super.init(name: "URLSession.dataTask")
    }

    override func execute() {
        let url = URL(string: receiverEndpoint("/"))!
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if error != nil {
                return self.fail()
            }
            if let data = data {
                if String(decoding: data, as: UTF8.self) != "hello" {
                    return self.fail()
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
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, _, error in
            if error != nil {
                return self.fail()
            }

            if let data = data {
                if String(decoding: data, as: UTF8.self) != "foobar" {
                    return self.fail()
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

class DownloadTaskTest: TestCase {
    init() {
        super.init(name: "URLSession.downloadTask")
    }

    override func execute() {
        let url = URL(string: receiverEndpoint("/"))!
        let task = URLSession.shared.downloadTask(with: url) { path, _, error in
            if error != nil {
                self.fail()
            }

            if let path = path {
                if let content = try? String(contentsOf: path) {
                    if content != "hello" {
                        self.fail()
                    }
                } else {
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
