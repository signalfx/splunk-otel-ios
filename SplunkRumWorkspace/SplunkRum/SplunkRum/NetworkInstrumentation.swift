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

import Foundation
import OpenTelemetryApi

let serverTimingPattern = #"traceparent;desc=['\"]00-([0-9a-f]{32})-([0-9a-f]{16})-01['\"]"#

func addLinkToSpan(span: Span, valStr: String) {
    // This is the worst regex interface I have ever seen in two+ decades of professional programming
    let regex = try! NSRegularExpression(pattern: serverTimingPattern)
    let result = regex.matches(in: valStr, range: NSRange(location: 0, length: valStr.utf16.count))
    // per standard regex logic, number of matched segments is 3 (whole match plus two () captures)
    if result.count != 1 || result[0].numberOfRanges != 3 {
        return
    }
    let traceId = String(valStr[Range(result[0].range(at: 1), in: valStr)!])
    let spanId = String(valStr[Range(result[0].range(at: 2), in: valStr)!])
    span.setAttribute(key: "link.traceId", value: traceId)
    span.setAttribute(key: "link.spanId", value: spanId)
}

func endHttpSpan(span: Span?, task: URLSessionTask) {
    if span == nil {
        return
    }
    let hr: HTTPURLResponse? = task.response as? HTTPURLResponse
    print("REsponse....")
    print(hr?.url?.absoluteString as Any)
    if hr != nil {
        span!.setAttribute(key: "http.status_code", value: hr!.statusCode)
        // Blerg, looks like an iteration here since it is case sensitive and the case insensitive search assumes single value
        for (key, val) in hr!.allHeaderFields {
            let keyStr = key as? String
            if keyStr != nil {
                if keyStr?.caseInsensitiveCompare("server-timing") == .orderedSame {
                    let valStr = val as? String
                    if valStr != nil {
                        if valStr!.starts(with: "traceparent") {
                            addLinkToSpan(span: span!, valStr: valStr!)
                        }
                    }
                }
            }
        }
    }
    if task.error != nil {
        span!.setAttribute(key: "error", value: true)
        span!.setAttribute(key: "exception.message", value: task.error!.localizedDescription)
        span!.setAttribute(key: "exception.type", value: String(describing: type(of: task.error!)))
    }
    span!.setAttribute(key: "http.response_content_length_uncompressed", value: Int(task.countOfBytesReceived))
    if task.countOfBytesSent != 0 {
        span!.setAttribute(key: "http.request_content_length", value: Int(task.countOfBytesSent))
    }
    if hostConnectionType != nil {
        span?.setAttribute(key: "net.host.connection.type", value: hostConnectionType!)
    }
    span!.end()
    print("http span ENDED....")
}

func startHttpSpan(request: URLRequest?) -> Span? {
    print("Request")
    print("http span started....")
    print(request?.url?.absoluteString as Any)
    if request == nil || request?.url == nil {
        return nil
    }
    let url = request!.url!
    if !(url.scheme?.lowercased().starts(with: "http") ?? false) {
        return nil
    }
    let method = request!.httpMethod ?? "GET"
    // Don't loop reporting on communication with the beacon
    let absUrlString = url.absoluteString
    if SplunkRum.theBeaconUrl != nil && absUrlString.starts(with: SplunkRum.theBeaconUrl!) {
        return nil
    }
    if SplunkRum.configuredOptions?.ignoreURLs != nil {
        let result = SplunkRum.configuredOptions?.ignoreURLs?.matches(in: absUrlString, range: NSRange(location: 0, length: absUrlString.utf16.count))
        if result?.count != 0 {
            return nil
        }
    }
    let tracer = buildTracer()
    let span = tracer.spanBuilder(spanName: "HTTP "+method).setSpanKind(spanKind: .client).startSpan()
    span.setAttribute(key: "component", value: "http")
    span.setAttribute(key: "http.url", value: url.absoluteString)
    span.setAttribute(key: "http.method", value: method)
    return span
}

class SessionTaskObserver: NSObject {
    var span: Span?
    // Observers aren't kept alive by observing...
    var extraRefToSelf: SessionTaskObserver?
    var lock: NSLock = NSLock()
    override init() {
        super.init()
        extraRefToSelf = self
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        lock.lock()
        defer {
            lock.unlock()
        }
        let task = object as? URLSessionTask
        if task == nil {
            return
        }
        if span == nil {
            span = startHttpSpan(request: task!.originalRequest)
        }
        // FIXME possibly also allow .canceling to close the span?
        if task!.state == .completed && extraRefToSelf != nil {
            endHttpSpan(span: span,
                        task: task!)
            task!.removeObserver(self, forKeyPath: "state")
            extraRefToSelf = nil
        }
    }
}

func wireUpTaskObserver(task: URLSessionTask) {
    task.addObserver(SessionTaskObserver(), forKeyPath: "state", options: .new, context: nil)
}

// swiftlint:disable missing_docs
extension URLSession {
    @objc open func splunk_swizzled_dataTask(with url: NSURL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let answer = splunk_swizzled_dataTask(with: url, completionHandler: completionHandler)
        wireUpTaskObserver(task: answer)
        return answer
       }

    @objc open func splunk_swizzled_dataTask(with url: NSURL) -> URLSessionDataTask {
        let answer = splunk_swizzled_dataTask(with: url)
        wireUpTaskObserver(task: answer)
        return answer
       }

    // rename objc view of func to allow "overloading"
    @objc(splunkSwizzledDataTaskWithRequest:completionHandler:) open func splunk_swizzled_dataTask(with request: URLRequest, completionHandler: ((Data?, URLResponse?, Error?) -> Void)?) -> URLSessionDataTask {
        let answer = splunk_swizzled_dataTask(with: request, completionHandler: completionHandler)
        wireUpTaskObserver(task: answer)
        return answer
       }

    @objc(splunkSwizzledDataTaskWithRequest:) open func splunk_swizzled_dataTask(with request: URLRequest) -> URLSessionDataTask {
        let answer = splunk_swizzled_dataTask(with: request)
        wireUpTaskObserver(task: answer)
        return answer
       }

    // uploads
    @objc open func splunk_swizzled_uploadTask(with: URLRequest, from: Data) -> URLSessionUploadTask {
        let answer = splunk_swizzled_uploadTask(with: with, from: from)
        wireUpTaskObserver(task: answer)
        return answer
    }
    @objc open func splunk_swizzled_uploadTask(with: URLRequest, from: Data, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
        let answer = splunk_swizzled_uploadTask(with: with, from: from, completionHandler: completionHandler)
        wireUpTaskObserver(task: answer)
        return answer
    }
    @objc open func splunk_swizzled_uploadTask(with: URLRequest, fromFile: NSURL) -> URLSessionUploadTask {
        let answer = splunk_swizzled_uploadTask(with: with, fromFile: fromFile)
        wireUpTaskObserver(task: answer)
        return answer
    }
    @objc open func splunk_swizzled_uploadTask(with: URLRequest, fromFile: NSURL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
        let answer = splunk_swizzled_uploadTask(with: with, fromFile: fromFile, completionHandler: completionHandler)
        wireUpTaskObserver(task: answer)
        return answer
    }
    @objc open func splunk_swizzled_uploadTask(withStreamedRequest: URLRequest) -> URLSessionUploadTask {
        let answer = splunk_swizzled_uploadTask(withStreamedRequest: withStreamedRequest)
        wireUpTaskObserver(task: answer)
        return answer
    }
    // download tasks
    @objc open func splunk_swizzled_downloadTask(with url: NSURL) -> URLSessionDownloadTask {
        let answer = splunk_swizzled_downloadTask(with: url)
        wireUpTaskObserver(task: answer)
        return answer
    }
    @objc open func splunk_swizzled_downloadTask(with url: NSURL, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        let answer = splunk_swizzled_downloadTask(with: url, completionHandler: completionHandler)
        wireUpTaskObserver(task: answer)
        return answer
       }

    @objc(splunkSwizzledDownloadTaskWithRequest: completionHandler:) open func splunk_swizzled_downloadTask(with request: URLRequest, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        let answer = splunk_swizzled_downloadTask(with: request, completionHandler: completionHandler)
        wireUpTaskObserver(task: answer)
        return answer
       }

    @objc(splunkSwizzledDownloadTaskWithRequest:) open func splunk_swizzled_downloadTask(with request: URLRequest) -> URLSessionDataTask {
        let answer = splunk_swizzled_downloadTask(with: request)
        wireUpTaskObserver(task: answer)
        return answer
       }
}

// FIXME use setImplementation and capture, rather than exchangeImpl
func swizzle(clazz: AnyClass, orig: Selector, swizzled: Selector) {
    let origM = class_getInstanceMethod(clazz, orig)
    let swizM = class_getInstanceMethod(clazz, swizzled)
    if origM != nil && swizM != nil {
        method_exchangeImplementations(origM!, swizM!)
    } else {
        debug_log("warning: could not swizzle "+NSStringFromSelector(orig))
    }
}

func initalizeNetworkInstrumentation() {
    let urlsession = URLSession.self

    // This syntax is obnoxious to differentiate with:request from with:url
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask),
            swizzled: #selector(URLSession.splunk_swizzled_dataTask(with:completionHandler:) as (URLSession) -> (NSURL, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask))

    swizzle(clazz: urlsession,
            orig: #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask),
            swizzled: #selector(URLSession.splunk_swizzled_dataTask(with:) as (URLSession) -> (NSURL) -> URLSessionDataTask))

    // @objc(overrrideName) requires a runtime lookup rather than a build-time lookup (seems like a bug in the compiler)
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask),
            swizzled: NSSelectorFromString("splunkSwizzledDataTaskWithRequest:completionHandler:"))

    swizzle(clazz: urlsession,
            orig: #selector(URLSession.dataTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDataTask),
            swizzled: NSSelectorFromString("splunkSwizzledDataTaskWithRequest:"))

    // upload tasks
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.uploadTask(with:from:)),
            swizzled: #selector(URLSession.splunk_swizzled_uploadTask(with:from:)))
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.uploadTask(with:from:completionHandler:)),
            swizzled: #selector(URLSession.splunk_swizzled_uploadTask(with:from:completionHandler:)))
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.uploadTask(with:fromFile:)),
            swizzled: #selector(URLSession.splunk_swizzled_uploadTask(with:fromFile:)))
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.uploadTask(with:fromFile:completionHandler:)),
            swizzled: #selector(URLSession.splunk_swizzled_uploadTask(with:fromFile:completionHandler:)))
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.uploadTask(withStreamedRequest:)),
            swizzled: #selector(URLSession.splunk_swizzled_uploadTask(withStreamedRequest:)))

    // download tasks
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.downloadTask(with:) as (URLSession) -> (URL) -> URLSessionDownloadTask),
            swizzled: #selector(URLSession.splunk_swizzled_downloadTask(with:) as (URLSession) -> (NSURL) -> URLSessionDownloadTask))
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask),
            swizzled: #selector(URLSession.splunk_swizzled_downloadTask(with:completionHandler:) as (URLSession) -> (NSURL, @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask))
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask),
            swizzled: NSSelectorFromString("splunkSwizzledDownloadTaskWithRequest:completionHandler:"))
    swizzle(clazz: urlsession,
            orig: #selector(URLSession.downloadTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDownloadTask),
            swizzled: NSSelectorFromString("splunkSwizzledDownloadTaskWithRequest:"))
    // FIXME figure out how to support the two ResumeData variants - state transfer is weird

}
