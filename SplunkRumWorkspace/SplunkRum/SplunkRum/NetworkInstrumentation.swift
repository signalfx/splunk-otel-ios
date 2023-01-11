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

func endHttpSpan(span: Span, task: URLSessionTask) {
    let hr: HTTPURLResponse? = task.response as? HTTPURLResponse
    if hr != nil {
        span.setAttribute(key: "http.status_code", value: hr!.statusCode)
        // Blerg, looks like an iteration here since it is case sensitive and the case insensitive search assumes single value
        for (key, val) in hr!.allHeaderFields {
            let keyStr = key as? String
            if keyStr != nil {
                if keyStr?.caseInsensitiveCompare("server-timing") == .orderedSame {
                    let valStr = val as? String
                    if valStr != nil {
                        if valStr!.starts(with: "traceparent") {
                            addLinkToSpan(span: span, valStr: valStr!)
                        }
                    }
                }
            }
        }
    }
    if task.error != nil {
        span.setAttribute(key: "error", value: true)
        span.setAttribute(key: "exception.message", value: task.error!.localizedDescription)
        span.setAttribute(key: "exception.type", value: String(describing: type(of: task.error!)))
    }
    span.setAttribute(key: "http.response_content_length_uncompressed", value: Int(task.countOfBytesReceived))
    if task.countOfBytesSent != 0 {
        span.setAttribute(key: "http.request_content_length", value: Int(task.countOfBytesSent))
    }
    span.end()
}

func isSupportedTask(task: URLSessionTask) -> Bool {
    return task is URLSessionDataTask || task is URLSessionDownloadTask || task is URLSessionUploadTask
}

func startHttpSpan(request: URLRequest?) -> Span? {
    if request?.url == nil {
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

    let networkInfo = getNetworkInfo()

    if networkInfo.hostConnectionType != nil {
        span.setAttribute(key: "net.host.connection.type", value: networkInfo.hostConnectionType!)
    }

    if networkInfo.hostConnectionSubType != nil {
        span.setAttribute(key: "net.host.connection.subtype", value: networkInfo.hostConnectionSubType!)
    }

    if networkInfo.carrierName != nil {
        span.setAttribute(key: "net.host.carrier.name", value: networkInfo.carrierName!)
    }

    if networkInfo.carrierCountryCode != nil {
        span.setAttribute(key: "net.host.carrier.mcc", value: networkInfo.carrierCountryCode!)
    }

    if networkInfo.carrierNetworkCode != nil {
        span.setAttribute(key: "net.host.carrier.mnc", value: networkInfo.carrierNetworkCode!)
    }

    if networkInfo.carrierIsoCountryCode != nil {
        span.setAttribute(key: "net.host.carrier.icc", value: networkInfo.carrierIsoCountryCode!)
    }

    return span
}

fileprivate var ASSOC_KEY_SPAN: UInt8 = 0

// swiftlint:disable missing_docs
extension URLSessionTask {
    @objc open func splunk_swizzled_setState(state: URLSessionTask.State) {
        defer {
            splunk_swizzled_setState(state: state)
        }

        if !isSupportedTask(task: self) {
            return
        }

        if state == URLSessionTask.State.running {
            return
        }

        if currentRequest?.url == nil {
            return
        }

        let maybeSpan: Span? = objc_getAssociatedObject(self, &ASSOC_KEY_SPAN) as? Span

        if maybeSpan == nil {
            return
        }

        endHttpSpan(span: maybeSpan!, task: self)
    }

    @objc open func splunk_swizzled_resume() {
        defer {
            splunk_swizzled_resume()
        }

        if !isSupportedTask(task: self) {
            return
        }

        if self.state == URLSessionTask.State.completed ||
            self.state == URLSessionTask.State.canceling {
            return
        }

        let existingSpan: Span? = objc_getAssociatedObject(self, &ASSOC_KEY_SPAN) as? Span

        if existingSpan != nil {
            return
        }

        startHttpSpan(request: currentRequest).map { span in
            objc_setAssociatedObject(self, &ASSOC_KEY_SPAN, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
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

func swizzledUrlSessionClasses() -> [AnyClass] {
    let conf = URLSessionConfiguration.ephemeral
    let session = URLSession(configuration: conf)
    // The URL is just something parseable, since empty string can not be provided
    let localDataTask = session.dataTask(with: URL(string: "https://splunkrum")!)

    defer {
        localDataTask.cancel()
        session.finishTasksAndInvalidate()
    }

    let setStateSelector = NSSelectorFromString("setState:")

    var classes: [AnyClass] = []
    guard var currentClass: AnyClass = object_getClass(localDataTask) else { return classes }
    var method = class_getInstanceMethod(currentClass, setStateSelector)

    while method != nil {
        let classResumeImp = method_getImplementation(method!)

        let superClass: AnyClass? = currentClass.superclass()
        let superClassMethod = class_getInstanceMethod(superClass, setStateSelector)
        let superClassResumeImp = superClassMethod.map { method_getImplementation($0) }

        if classResumeImp != superClassResumeImp {
            classes.append(currentClass)
        }

        if superClass == nil {
            return classes
        }

        currentClass = superClass!
        method = superClassMethod
    }

    return classes
}

func swizzleUrlSession() {
    let classes = swizzledUrlSessionClasses()

    let setStateSelector = NSSelectorFromString("setState:")
    let resumeSelector = NSSelectorFromString("resume")

    for classToSwizzle in classes {
        swizzle(clazz: classToSwizzle, orig: setStateSelector, swizzled: #selector(URLSessionTask.splunk_swizzled_setState(state:)))
        swizzle(clazz: classToSwizzle, orig: resumeSelector, swizzled: #selector(URLSessionTask.splunk_swizzled_resume))
    }
}

func initalizeNetworkInstrumentation() {
    swizzleUrlSession()
}
