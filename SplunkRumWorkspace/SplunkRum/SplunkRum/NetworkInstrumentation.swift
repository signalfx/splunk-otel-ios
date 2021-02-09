import Foundation
import OpenTelemetryApi

let serverTimingPattern = #"traceparent;desc=\"00-([0-9a-f]{32})-([0-9a-f]{16})-01\""#

public func addLinkToSpan(span: Span, valStr: String) {
    // FIXME this is the worst regex interface I have ever seen in two+ decades of professional programming
    let regex = try! NSRegularExpression(pattern: serverTimingPattern)
    let result = regex.matches(in: valStr, range: NSRange(location: 0, length: valStr.utf16.count))
    // per standard regex logic, number of matched segments is 3 (whole match plus two () captures)
    if result.count != 1 || result[0].numberOfRanges != 3 {
        return
    }
    // FIXME more nil checks, etc. through here -> great candidate for unit testing
    let traceId = String(valStr[Range(result[0].range(at: 1), in: valStr)!])
    let spanId = String(valStr[Range(result[0].range(at: 2), in: valStr)!])
    span.setAttribute(key: "link.traceId", value: traceId)
    span.setAttribute(key: "link.spanId", value: spanId)
}

func endHttpSpan(span: Span, data: Data?, response: URLResponse?, error: Error?) {
    let hr: HTTPURLResponse? = response as? HTTPURLResponse
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
    if error != nil {
        span.setAttribute(key: "error", value: true)
        span.setAttribute(key: "error.message", value: error!.localizedDescription)
        // FIXME what else can be divined?
    }
    if data != nil {
        span.setAttribute(key: "http.response_content_length_uncompressed", value: data!.count)
    }
    span.end()
}

func startHttpSpan(url: URL, method: String) -> Span? {
    // FIXME even without the hardcode, this is a hokey way to supress spans from the zipkin exporter
    if url.absoluteString.contains("auth=") {
        return nil
    }
    // FIXME constants for this stuff
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios", instrumentationVersion: "0.0.1")
    let span = tracer.spanBuilder(spanName: "HTTP "+method).startSpan()
    // FIXME http.method, try for http.response_content_length and http.request_content_length
    span.setAttribute(key: "http.url", value: url.absoluteString)
    span.setAttribute(key: "http.method", value: method)
    return span
}

func startHttpSpan(request: URLRequest) -> Span? {
    if request.url != nil {
        return startHttpSpan(url: request.url!, method: request.httpMethod ?? "GET")
    }
    return nil
}

extension URLSession {
    // FIXME repeat ad nauseum for all the public *Tasks, but also consider cases where no completion handler is provided

    @objc open func swizzled_dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let span = startHttpSpan(url: url, method: "GET")
        return swizzled_dataTask(with: url) {(data, response, error) in
            // FIXME try/catch equiv
            completionHandler(data, response, error)
            if span != nil {
                endHttpSpan(span: span!, data: data, response: response, error: error)
            }
        }
       }

    @objc open func swizzled_dataTask(with url: URL) -> URLSessionDataTask {
        let span = startHttpSpan(url: url, method: "GET")
        return swizzled_dataTask(with: url) {(data, response, error) in
            // no user-provided callback, just our own
            if span != nil {
                endHttpSpan(span: span!, data: data, response: response, error: error)
            }
        }
       }

    // rename objc view of func to allow "overloading"
    @objc(swizzledDataTaskWithRequest: completionHandler:) open func swizzled_dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let span = startHttpSpan(request: request)
        return swizzled_dataTask(with: request) {(data, response, error) in
            // FIXME try/catch equiv
            completionHandler(data, response, error)
            if span != nil {
                endHttpSpan(span: span!, data: data, response: response, error: error)
            }
        }
       }

    @objc(swizzledDataTaskWithRequest:) open func swizzled_dataTask(with request: URLRequest) -> URLSessionDataTask {
        let span = startHttpSpan(request: request)
        return swizzled_dataTask(with: request) {(data, response, error) in
            // no user-provided callback, just our own
            if span != nil {
                endHttpSpan(span: span!, data: data, response: response, error: error)
            }
        }
       }
}
func initalizeNetworkInstrumentation() {
    // FIXME do this also to .emphemeral and results of the function .background(withIdentifier)
    // FIXME also use setImplementation and capture, rather than exchangeImpls
    let c = URLSession.self
    // This syntax is obnoxious to differentiate with:request from with:url
    var orig = class_getInstanceMethod(c, #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask))
    var swizzled = class_getInstanceMethod(c, #selector(URLSession.swizzled_dataTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask))
    if swizzled != nil && orig != nil {
        method_exchangeImplementations(orig!, swizzled!)
    } else {
        // FIXME logging
        print("warning: couldn't swizzle 1")
    }

    // FIXME just copy+pasting for now to get a feel for how to factor this stuff
    orig = class_getInstanceMethod(c, #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask))
    swizzled = class_getInstanceMethod(c, #selector(URLSession.swizzled_dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask))
    if swizzled != nil && orig != nil {
        method_exchangeImplementations(orig!, swizzled!)
    } else {
        print("warning: couldn't swizzle 2")
    }

    orig = class_getInstanceMethod(c, #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask))
    // @objc(overrrideName) requires a runtime lookup rather than a build-time lookup (seems like a bug in the compiler)
    swizzled = class_getInstanceMethod(c, NSSelectorFromString("swizzledDataTaskWithRequest:completionHandler:"))
    if swizzled != nil && orig != nil {
        method_exchangeImplementations(orig!, swizzled!)
    } else {
        print("warning: couldn't swizzle 3")
    }

    orig = class_getInstanceMethod(c, #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask))
    swizzled = class_getInstanceMethod(c, NSSelectorFromString("swizzledDataTaskWithRequest:"))
    if swizzled != nil && orig != nil {
        method_exchangeImplementations(orig!, swizzled!)
    } else {
        print("warning: couldn't swizzle 4")
    }

}
