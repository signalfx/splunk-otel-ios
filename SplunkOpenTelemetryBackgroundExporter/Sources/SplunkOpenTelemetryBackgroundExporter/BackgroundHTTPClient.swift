//
/*
Copyright 2025 Splunk Inc.

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

import CiscoDiskStorage
internal import CiscoLogger
import Foundation
import SplunkCommon

/// Client for sending requests over HTTP.
final class BackgroundHTTPClient: NSObject {

    // MARK: - Private properties

    private let urlSessionDelegateQueue: OperationQueue
    private let sessionQosConfiguration: SessionQOSConfiguration
    private let nameSpace: String

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "BackgroundExporter")

    private let diskStorage: DiskStorage


    // MARK: - Computed properties

    private lazy var session: URLSession = {
        let identifier = "com.otel.config.session.\(nameSpace)"
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)

        configuration.networkServiceType = .background
        configuration.isDiscretionary = false
        configuration.allowsCellularAccess = sessionQosConfiguration.allowsCellularAccess
        configuration.allowsConstrainedNetworkAccess = sessionQosConfiguration.allowsConstrainedNetworkAccess
        configuration.allowsExpensiveNetworkAccess = sessionQosConfiguration.allowsExpensiveNetworkAccess

        return URLSession(configuration: configuration, delegate: self, delegateQueue: urlSessionDelegateQueue)
    }()


    // MARK: - Initialization

    init(sessionQosConfiguration: SessionQOSConfiguration, diskStorage: DiskStorage, namespace: String) {
        self.sessionQosConfiguration = sessionQosConfiguration
        self.diskStorage = diskStorage
        self.nameSpace = namespace

        urlSessionDelegateQueue = OperationQueue("URLSessionDelegate-\(namespace)", maxConcurrents: 1, qualityOfService: .utility)

        super.init()
    }


    // MARK: - Client logic

    func send(_ requestDescriptor: RequestDescriptor) throws {
        let fileKey = KeyBuilder(
            requestDescriptor.id.uuidString,
            parrentKeyBuilder: KeyBuilder.uploadsKey.append(requestDescriptor.fileKeyType)
        )

        guard requestDescriptor.shouldSend else {
            logger.log(level: .info) {
                "Maximal retry sent count exceeded for the given taskDescription: \(requestDescriptor)."
            }

            try diskStorage.delete(forKey: fileKey)

            return
        }

        let fileUrl = try diskStorage.finalDestination(forKey: fileKey)

        guard FileManager.default.fileExists(atPath: fileUrl.path) else {
            logger.log(level: .error) {
                "File does not exist at path: \(fileUrl)."
            }

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

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard
            let httpResponse = dataTask.response as? HTTPURLResponse,
            let receivedData = String(data: data, encoding: .utf8),
            !(200 ... 299).contains(httpResponse.statusCode),
            let taskDescription = dataTask.taskDescription,
            let requestDescriptor = try? JSONDecoder().decode(RequestDescriptor.self, from: Data(taskDescription.utf8))
        else {
            return
        }

        logger.log(level: .info) {
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

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard
            let taskDescription = task.taskDescription,
            let requestDescriptor = try? JSONDecoder().decode(RequestDescriptor.self, from: Data(taskDescription.utf8))
        else {
            logger.log(level: .info) {
                "Failed to reconstruct request descriptor for a request with an empty taskDescription: \(String(describing: task.taskDescription))."
            }

            return
        }

        if let error {
            logger.log(level: .info) {
                """
                Request to: \(requestDescriptor.endpoint.absoluteString) \n
                with a data task id: \(requestDescriptor.id) \n
                failed with an error message: \(error.localizedDescription).
                """
            }

            try? send(requestDescriptor)
        }
        else {
            if let httpResponse = task.response as? HTTPURLResponse {
                logger.log(level: .info) {
                    """
                    Request to: \(requestDescriptor.endpoint.absoluteString) with id \(requestDescriptor.id.uuidString) \n
                    has been received with status code \(httpResponse.statusCode).
                    """
                }
            }

            try? diskStorage.delete(
                forKey: KeyBuilder(
                    requestDescriptor.id.uuidString,
                    parrentKeyBuilder: KeyBuilder.uploadsKey.append(requestDescriptor.fileKeyType)
                )
            )
        }
    }
}
