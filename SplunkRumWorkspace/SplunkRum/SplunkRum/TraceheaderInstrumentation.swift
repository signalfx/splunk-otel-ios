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

extension URLSession {
    @objc public enum TaskType: Int {
        case data, download, upload
    }
    
    //MARK: Data Tasks
    @objc open func splunk_swizzled_dataTask(with request: URLRequest) -> URLSessionDataTask {
        let noopHandler: @Sendable (Data?, URLResponse?, Error?) -> Void = { _,_,_ in }
        if let task = injectedSessionTask(request: request, type: .data, completionHandler: noopHandler) as? URLSessionDataTask {
            return task
        }
        return splunk_swizzled_dataTask(with: request)
    }
    
    @objc open func splunk_swizzled_dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        if let task = injectedSessionTask(request: request, type: .data, completionHandler: completionHandler) as? URLSessionDataTask {
            return task
        }
        return splunk_swizzled_dataTask(with: request, completionHandler: completionHandler)
    }

    @objc open func splunk_swizzled_UrlDataTask(with url: URL) -> URLSessionDataTask {
        let noopHandler: @Sendable (Data?, URLResponse?, Error?) -> Void = { _,_,_ in }
        if let task = injectedSessionTask(request: URLRequest(url: url), type: .data, completionHandler: noopHandler) as? URLSessionDataTask {
            return task
        }
        return splunk_swizzled_UrlDataTask(with: url)
    }
    
    @objc open func splunk_swizzled_UrlDataTask(with url: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        if let task = injectedSessionTask(request: URLRequest(url: url), type: .data, completionHandler: completionHandler) as? URLSessionDataTask {
            return task
        }
        return splunk_swizzled_UrlDataTask(with: url, completionHandler: completionHandler)
    }
    
    //MARK: Upload Tasks
    @objc open func splunk_swizzled_uploadTask(with request: URLRequest, from bodyData: Data) -> URLSessionUploadTask {
        let sessionTaskId = UUID().uuidString
        var task = splunk_swizzled_uploadTask(with: request, from: bodyData)
        if SplunkRum.configuredOptions?.enableTraceparentOnRequest == true,
            objc_getAssociatedObject(request, &ASSOC_KEY_TRACE_REQ) == nil{
            var instrumentedRequest = request
            task = splunk_swizzled_uploadTask(with: instrumentedRequest, from: bodyData)
            startHttpSpan(request: instrumentedRequest).map { span in
                instrumentedRequest.addValue(traceparentHeader(span: span), forHTTPHeaderField: "traceparent")
                objc_setAssociatedObject(task, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
        }
        setTraceKey(value: sessionTaskId, for: task)
        return task
    }
    
    @objc open func splunk_swizzled_uploadTask(with request: URLRequest, from bodyData: Data, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
        let sessionTaskId = UUID().uuidString
        var task = splunk_swizzled_uploadTask(with: request, from: bodyData, completionHandler: completionHandler)
        if SplunkRum.configuredOptions?.enableTraceparentOnRequest == true,
            objc_getAssociatedObject(request, &ASSOC_KEY_TRACE_REQ) == nil{
            var instrumentedRequest = request
            task = splunk_swizzled_uploadTask(with: instrumentedRequest, from: bodyData, completionHandler: completionHandler)
            startHttpSpan(request: instrumentedRequest).map { span in
                instrumentedRequest.addValue(traceparentHeader(span: span), forHTTPHeaderField: "traceparent")
                objc_setAssociatedObject(task, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
        }
        setTraceKey(value: sessionTaskId, for: task)
        return task
    }
    
    @objc open func splunk_swizzled_uploadTask(with request: URLRequest, fromFile fileURL: URL) -> URLSessionUploadTask {
        let sessionTaskId = UUID().uuidString
        var task = splunk_swizzled_uploadTask(with: request, fromFile: fileURL)
        if SplunkRum.configuredOptions?.enableTraceparentOnRequest == true,
            objc_getAssociatedObject(request, &ASSOC_KEY_TRACE_REQ) == nil{
            var instrumentedRequest = request
            task = splunk_swizzled_uploadTask(with: instrumentedRequest, fromFile: fileURL)
            startHttpSpan(request: instrumentedRequest).map { span in
                instrumentedRequest.addValue(traceparentHeader(span: span), forHTTPHeaderField: "traceparent")
                objc_setAssociatedObject(task, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
        }
        setTraceKey(value: sessionTaskId, for: task)
        return task
    }
    
    @objc open func splunk_swizzled_uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
        let sessionTaskId = UUID().uuidString
        var task = splunk_swizzled_uploadTask(with: request, fromFile: fileURL, completionHandler: completionHandler)
        if SplunkRum.configuredOptions?.enableTraceparentOnRequest == true,
            objc_getAssociatedObject(request, &ASSOC_KEY_TRACE_REQ) == nil{
            var instrumentedRequest = request
            task = splunk_swizzled_uploadTask(with: instrumentedRequest, fromFile: fileURL, completionHandler: completionHandler)
            startHttpSpan(request: instrumentedRequest).map { span in
                instrumentedRequest.addValue(traceparentHeader(span: span), forHTTPHeaderField: "traceparent")
                objc_setAssociatedObject(task, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
        }
        setTraceKey(value: sessionTaskId, for: task)
        return task
    }
    
    @objc open func splunk_swizzled_uploadTask(withStreamedRequest request: URLRequest) -> URLSessionUploadTask {
        let noopHandler: @Sendable (URL?, URLResponse?, Error?) -> Void = { _,_,_ in }
        if let task = injectedSessionTask(request: request, type: .upload, completionHandler: noopHandler) as? URLSessionUploadTask {
            return task
        }
        return splunk_swizzled_uploadTask(withStreamedRequest: request)
    }
    
    //MARK: Download Tasks
    @objc open func splunk_swizzled_downloadTask(with request: URLRequest) -> URLSessionDownloadTask {
        let noopHandler: @Sendable (URL?, URLResponse?, Error?) -> Void = { _,_,_ in }
        if let task = injectedSessionTask(request: request, type: .download, completionHandler: noopHandler) as? URLSessionDownloadTask {
            return task
        }
        return splunk_swizzled_downloadTask(with: request)
    }
    
    @objc open func splunk_swizzled_downloadTask(with request: URLRequest, completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        if let task = injectedSessionTask(request: request, type: .download, completionHandler: completionHandler) as? URLSessionDownloadTask {
            return task
        }
        return splunk_swizzled_downloadTask(with: request, completionHandler: completionHandler)
    }
    
    @objc open func splunk_swizzled_UrlDownloadTask(with url: URL) -> URLSessionDownloadTask {
        let noopHandler: @Sendable (URL?, URLResponse?, Error?) -> Void = { _,_,_ in }
        if let task = injectedSessionTask(request: URLRequest(url: url), type: .download, completionHandler: noopHandler) as? URLSessionDownloadTask {
            return task
        }
        return splunk_swizzled_UrlDownloadTask(with: url)
    }
    
    @objc open func splunk_swizzled_UrlDownloadTask(with url: URL, completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        if let task = injectedSessionTask(request: URLRequest(url: url), type: .download, completionHandler: completionHandler) as? URLSessionDownloadTask {
            return task
        }
        return splunk_swizzled_UrlDownloadTask(with: url, completionHandler: completionHandler)
    }
    
    // MARK: Helper funcs
    func injectedSessionTask<T>(request: URLRequest, type: TaskType, completionHandler: @escaping (@Sendable (T?, URLResponse?, Error?) -> Void)) -> URLSessionTask {
        let sessionTaskId = UUID().uuidString
        var task: URLSessionTask = callFunctionForTaskType(type: type, request: request, completionHandler: completionHandler)
        
        if SplunkRum.configuredOptions?.enableTraceparentOnRequest == true,
            objc_getAssociatedObject(request, &ASSOC_KEY_TRACE_REQ) == nil {
            var instrumentedRequest = request
            if let span = startHttpSpan(request: instrumentedRequest) {
                instrumentedRequest.addValue(traceparentHeader(span: span), forHTTPHeaderField: "traceparent")
                objc_setAssociatedObject(task, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
                task = callFunctionForTaskType(type: type, request: instrumentedRequest, completionHandler: completionHandler)
            }
        }
        setTraceKey(value: sessionTaskId, for: task)
        return task
    }
    
    fileprivate func setTraceKey(value: String, for task: URLSessionTask) {
        objc_setAssociatedObject(task, &ASSOC_KEY_TRACE_REQ, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    fileprivate func traceparentHeader(span: Span) -> String {
        let version = "00"
        let traceId = span.context.traceId.hexString
        let spanId = span.context.spanId.hexString
        let sampled = span.context.isSampled ? "01" : "00"
        return [version, traceId, spanId, sampled].joined(separator: "-")
    }
    /*
    func callFunctionForTaskType(type: TaskType, request: URLRequest) -> URLSessionTask {
        switch type {
            case .data:
                return splunk_swizzled_dataTask(with: request)
            case .download:
                return splunk_swizzled_downloadTask(with: request)
            case .upload:
                return splunk_swizzled_uploadTask(withStreamedRequest: request)
        }
    }
    */
    func callFunctionForTaskType<T>(type: TaskType, request: URLRequest, completionHandler: (@escaping @Sendable (T?, URLResponse?, Error?) -> Void)) -> URLSessionTask {
        switch type {
            case .data:
                let handler = completionHandler as! @Sendable (Data?, URLResponse?, Error?) -> Void
                return splunk_swizzled_dataTask(with: request, completionHandler: handler)
            case .download:
                let handler = completionHandler as! @Sendable (URL?, URLResponse?, Error?) -> Void
                return splunk_swizzled_downloadTask(with: request, completionHandler: handler)
            case .upload:
                return splunk_swizzled_uploadTask(withStreamedRequest: request)
        }
    }
}
