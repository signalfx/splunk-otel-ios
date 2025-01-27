//
/*
Copyright 2024 Splunk Inc.

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
import SplunkLogger

/// Client for sending requests over HTTP.
final class BackgroundHTTPClient: NSObject {

    // MARK: - Private properties

    private let urlSessionDelegateQueue = OperationQueue("URLSessionDelegate", maxConcurrents: 1, qualityOfService: .utility)
    private let sessionQosConfiguration: SessionQOSConfiguration

    private let internalLogger = InternalLogger(configuration: .backgroundExporter(category: "BackgroundHTTPClient"))


    // MARK: - Computed properties

    private lazy var session: URLSession = {
        let identifier = "com.otel.config.session"
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)

        configuration.networkServiceType = .background
        configuration.isDiscretionary = false
        configuration.allowsCellularAccess = sessionQosConfiguration.allowsCellularAccess
        configuration.allowsConstrainedNetworkAccess = sessionQosConfiguration.allowsConstrainedNetworkAccess
        configuration.allowsExpensiveNetworkAccess = sessionQosConfiguration.allowsExpensiveNetworkAccess

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: urlSessionDelegateQueue)

        return session
    }()


    // MARK: - Initialization

    init(sessionQosConfiguration: SessionQOSConfiguration) {
        self.sessionQosConfiguration = sessionQosConfiguration
        super.init()
    }


    // MARK: - Client logic

    func send(_ requestDescriptor: RequestDescriptor) {

        guard
            let fileUrl = DiskCache.cache(subfolder: .uploadFiles, item: requestDescriptor.id.uuidString),
            DiskCache.fileExists(at: fileUrl)
        else {
            self.internalLogger.log(level: .info) {
                "File to upload doesn't exist for the given taskDescription: \(requestDescriptor)."
            }

            return
        }

        guard requestDescriptor.shouldSend else {
            self.internalLogger.log(level: .info) {
                "Maximal retry sent count exceeded for the given taskDescription: \(requestDescriptor)."
            }

            DiskCache.clean(item: requestDescriptor.id.uuidString, in: .uploadFiles)
            return
        }

        let task = session.uploadTask(
            with: requestDescriptor.createRequest(),
            fromFile: fileUrl
        )

        task.earliestBeginDate = requestDescriptor.scheduled

        var sentRequestDescriptor = requestDescriptor
        sentRequestDescriptor.sentCount += 1

        task.taskDescription = sentRequestDescriptor.json
        task.resume()
    }

    func flush(completion: @escaping () -> Void) {
        session.flush(completionHandler: completion)
    }

    func getAllSessionsTasks(_ completionHandler: @escaping ([URLSessionTask]) -> Void) {
        session.getAllTasks { tasks in
            completionHandler(tasks)
        }
    }
}

extension BackgroundHTTPClient: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard
            let httpResponse = dataTask.response as? HTTPURLResponse,
            let receivedData = String(data: data, encoding: .utf8),
            !(200...299).contains(httpResponse.statusCode),
            let taskDescription = dataTask.taskDescription,
            let requestDescriptor = try? JSONDecoder().decode(RequestDescriptor.self, from: Data(taskDescription.utf8))
        else {
            return
        }

        self.internalLogger.log(level: .info) {
            """
            Request to: \(requestDescriptor.endpoint.absoluteString) \n
            with a data task id: \(requestDescriptor.id) \n
            failed with an error status code: \(httpResponse.statusCode) \n
            and error message: \(receivedData).
            """
        }
    }
}

extension BackgroundHTTPClient: URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard
            let taskDescription = task.taskDescription,
            let requestDescriptor = try? JSONDecoder().decode(RequestDescriptor.self, from: Data(taskDescription.utf8))
        else {
            self.internalLogger.log(level: .info) {
                "Failed to reconstruct request descriptor for a request with an empty taskDescription: \(String(describing: task.taskDescription))."
            }

            return
        }

        if
            let httpResponse = task.response as? HTTPURLResponse,
            !(200...299).contains(httpResponse.statusCode)
        {
            self.internalLogger.log(level: .info) {
                """
                Request to: \(requestDescriptor.endpoint.absoluteString) \n
                with a data task id: \(requestDescriptor.id) \n
                failed with an error status code: \(httpResponse.statusCode).
                """
            }

            send(requestDescriptor)
        }
        else if let error {
            self.internalLogger.log(level: .info) {
                """
                Request to: \(requestDescriptor.endpoint.absoluteString) \n
                with a data task id: \(requestDescriptor.id) \n
                failed with an error message: \(error.localizedDescription).
                """
            }

            send(requestDescriptor)
        } else {

            if let httpResponse = task.response as? HTTPURLResponse {
                self.internalLogger.log(level: .info) {
                    """
                    Request to: \(requestDescriptor.endpoint.absoluteString) \n
                    has been successfully received with status code \(httpResponse.statusCode).
                    """
                }
            }

            DiskCache.clean(item: requestDescriptor.id.uuidString, in: .uploadFiles)
        }
    }
}
