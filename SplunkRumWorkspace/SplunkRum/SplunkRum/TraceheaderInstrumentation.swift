//
/*
Copyright 2021 Splunk Inc.

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

/*
 Classes adapted from opentelemetry-swift URLSessionInstrumentation.swift, v1.7.0
 https://github.com/open-telemetry/opentelemetry-swift
 */

import Foundation

fileprivate var ASSOC_KEY_SPAN: UInt8 = 0
fileprivate var idKey: Void?

func swizzleUrlSessionTask() {
    URLSessionTask.injectIntoNSURLSessionCreateTaskMethods()
    URLSessionTask.injectIntoNSURLSessionCreateTaskWithParameterMethods()
    URLSessionTask.injectIntoNSURLSessionAsyncUploadTaskMethods()
    URLSessionTask.injectIntoNSURLSessionAsyncDataAndDownloadTaskMethods()
}

extension URLSessionTask {
    fileprivate class func injectIntoNSURLSessionCreateTaskMethods() {
        let cls = URLSession.self
        [
            #selector(URLSession.dataTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDataTask),
            #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask),
            #selector(URLSession.uploadTask(withStreamedRequest:)),
            #selector(URLSession.downloadTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDownloadTask),
            #selector(URLSession.downloadTask(with:) as (URLSession) -> (URL) -> URLSessionDownloadTask),
            #selector(URLSession.downloadTask(withResumeData:))
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto failed")
                return
            }
            var originalIMP: IMP?

            let block: @convention(block) (URLSession, AnyObject) -> URLSessionTask = { session, argument in
                if let url = argument as? URL {
                    let request = URLRequest(url: url)
                    if SplunkRum.configuredOptions?.enableTraceparentOnRequest == true {
                        if selector == #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask) {
                            return session.dataTask(with: request)
                        } else {
                            return session.downloadTask(with: request)
                        }
                    }
                }

                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (URLSession, Selector, Any) -> URLSessionDataTask).self)
                var task: URLSessionTask
                let sessionTaskId = UUID().uuidString

                if let request = argument as? URLRequest, objc_getAssociatedObject(argument, &idKey) == nil {
                    var instrumentedRequest = request
                    startHttpSpan(request: instrumentedRequest).map { span in
                        instrumentedRequest.addValue(URLSessionTask.traceparentHeader(span: span), forHTTPHeaderField: "traceparent")
                        objc_setAssociatedObject(self, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
                    }
                    task = castedIMP(session, selector, instrumentedRequest)
                } else {
                    task = castedIMP(session, selector, argument)
                    if objc_getAssociatedObject(argument, &idKey) == nil, let currentRequest = task.currentRequest {
                        startHttpSpan(request: currentRequest).map { span in
                            objc_setAssociatedObject(self, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
                        }
                    }
                }
                URLSessionTask.setIdKey(value: sessionTaskId, for: task)
                return task
            }
            let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            originalIMP = method_setImplementation(original, swizzledIMP)
        }
    }

    fileprivate class func injectIntoNSURLSessionCreateTaskWithParameterMethods() {
        let cls = URLSession.self
        [
            #selector(URLSession.uploadTask(with:from:)),
            #selector(URLSession.uploadTask(with:fromFile:))
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?

            let block: @convention(block) (URLSession, URLRequest, AnyObject) -> URLSessionTask = { session, request, argument in
                let sessionTaskId = UUID().uuidString
                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (URLSession, Selector, URLRequest, AnyObject) -> URLSessionDataTask).self)
                var instrumentedRequest = request
                startHttpSpan(request: instrumentedRequest).map { span in
                    instrumentedRequest.addValue(URLSessionTask.traceparentHeader(span: span), forHTTPHeaderField: "traceparent")
                    objc_setAssociatedObject(self, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
                }
                let task = castedIMP(session, selector, instrumentedRequest, argument)
                URLSessionTask.setIdKey(value: sessionTaskId, for: task)
                return task
            }
            let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            originalIMP = method_setImplementation(original, swizzledIMP)
        }
    }

    fileprivate class func injectIntoNSURLSessionAsyncDataAndDownloadTaskMethods() {
        let cls = URLSession.self
        [
            #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask),
            #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask),
            #selector(URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask),
            #selector(URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask),
            #selector(URLSession.downloadTask(withResumeData:completionHandler:))
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?

            let block: @convention(block) (URLSession, AnyObject, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionTask = { session, argument, completion in

                if let url = argument as? URL {
                    let request = URLRequest(url: url)

                    if SplunkRum.configuredOptions?.enableTraceparentOnRequest == true {
                        if selector == #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask) {
                            if let completion = completion {
                                return session.dataTask(with: request, completionHandler: completion)
                            } else {
                                return session.dataTask(with: request)
                            }
                        } else {
                            if let completion = completion {
                                return session.downloadTask(with: request, completionHandler: completion)
                            } else {
                                return session.downloadTask(with: request)
                            }
                        }
                    }
                }

                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (URLSession, Selector, Any, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionDataTask).self)
                var task: URLSessionTask!
                let sessionTaskId = UUID().uuidString

                var completionBlock = completion

                if completionBlock != nil {
                    if objc_getAssociatedObject(argument, &idKey) == nil {
                        let completionWrapper: (Any?, URLResponse?, Error?) -> Void = { object, response, error in
                            if let error = error {
                                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                                print("Error injecting traceparent into selector: %@, status code: %@", error, status)
                            } else {
                                print("Error injecting traceparent into selector")
                            }
                            if let completion = completion {
                                completion(object, response, error)
                            } else {
                                (session.delegate as? URLSessionTaskDelegate)?.urlSession?(session, task: task, didCompleteWithError: error)
                            }
                        }
                        completionBlock = completionWrapper
                    }
                }

                if let request = argument as? URLRequest, objc_getAssociatedObject(argument, &idKey) == nil {
                    var instrumentedRequest = request
                    startHttpSpan(request: instrumentedRequest).map { span in
                        instrumentedRequest.addValue(URLSessionTask.traceparentHeader(span: span), forHTTPHeaderField: "traceparent")
                        objc_setAssociatedObject(self, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
                    }
                    task = castedIMP(session, selector, instrumentedRequest, completionBlock)
                } else {
                    task = castedIMP(session, selector, argument, completionBlock)
                    if objc_getAssociatedObject(argument, &idKey) == nil,
                       let currentRequest = task.currentRequest {
                        startHttpSpan(request: currentRequest).map { span in
                            objc_setAssociatedObject(self, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
                        }
                    }
                }
                URLSessionTask.setIdKey(value: sessionTaskId, for: task)
                return task
            }
            let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            originalIMP = method_setImplementation(original, swizzledIMP)
        }
    }

    fileprivate class func injectIntoNSURLSessionAsyncUploadTaskMethods() {
        let cls = URLSession.self
        [
            #selector(URLSession.uploadTask(with:from:completionHandler:)),
            #selector(URLSession.uploadTask(with:fromFile:completionHandler:))
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?

            let block: @convention(block) (URLSession, URLRequest, AnyObject, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionTask = { session, request, argument, completion in

                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (URLSession, Selector, URLRequest, AnyObject, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionDataTask).self)

                var task: URLSessionTask!
                let sessionTaskId = UUID().uuidString

                var completionBlock = completion
                if objc_getAssociatedObject(argument, &idKey) == nil {
                    let completionWrapper: (Any?, URLResponse?, Error?) -> Void = { object, response, error in
                        if let error = error {
                            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                            print("Error injecting traceparent into selector: %@, status code: %@", error, status)
                        } else {
                            print("Error injecting traceparent into selector")
                        }
                        if let completion = completion {
                            completion(object, response, error)
                        } else {
                            (session.delegate as? URLSessionTaskDelegate)?.urlSession?(session, task: task, didCompleteWithError: error)
                        }
                    }
                    completionBlock = completionWrapper
                }

                var instrumentedRequest = request
                startHttpSpan(request: instrumentedRequest).map { span in
                    instrumentedRequest.addValue(URLSessionTask.traceparentHeader(span: span), forHTTPHeaderField: "traceparent")
                    objc_setAssociatedObject(self, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
                }
                task = castedIMP(session, selector, instrumentedRequest, argument, completionBlock)

                URLSessionTask.setIdKey(value: sessionTaskId, for: task)
                return task
            }
            let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            originalIMP = method_setImplementation(original, swizzledIMP)
        }
    }

    fileprivate class func setIdKey(value: String, for task: URLSessionTask) {
        objc_setAssociatedObject(task, &idKey, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    fileprivate class func traceparentHeader(span: Span) -> String {
        let version = "00"
        let traceId = span.context.traceId.hexString
        let spanId = span.context.spanId.hexString
        let sampled = span.context.isSampled ? "01" : "00"
        return [version, traceId, spanId, sampled].joined(separator: "-")
    }
}
