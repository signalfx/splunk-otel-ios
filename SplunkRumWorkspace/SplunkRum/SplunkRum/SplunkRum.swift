import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import ZipkinExporter
import UIKit

// Hooking URLSession constructor doesn't do anythinng for URLSession.default

// NSSessiontask init(session: URLSession, request: URLRequest, taskIdentifier: Int, body: _Body?) ?

// URLSession func dataTask(with request: _Request, behaviour: _TaskRegistry._Behaviour) -> URLSessionDataTask {
// Also uploadTask and downloadTask from same file
// https://github.com/apple/swift-corelibs-foundation/blob/8f08574618e2654ccda730301e31aa73ecc4c5dc/Sources/FoundationNetworking/URLSession/URLSession.swift

let serverTimingPattern = #"traceparent;desc=\"00-([0-9a-f]{32})-([0-9a-f]{16})-01\""#

public func addLinkToSpan(span: Span, valStr: String) {
    // FIXME this is the worst regex interface I have ever seen in two+ decades of professional programming
    let regex = try! NSRegularExpression(pattern: serverTimingPattern)
    let result = regex.matches(in:valStr, range:NSMakeRange(0, valStr.utf16.count))
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
func endHttpSpan(span: Span, data: Data?, response: URLResponse?, error:Error?) {
    let hr: HTTPURLResponse? = response as? HTTPURLResponse
    if (hr != nil) {
        span.setAttribute(key: "http.status_code", value: hr!.statusCode)
        // Blerg, looks like an iteration here since it is case sensitive and the case insensitive search assumes single value
        for (key, val) in hr!.allHeaderFields {
            let keyStr = key as? String
            if (keyStr != nil) {
                if (keyStr?.caseInsensitiveCompare("server-timing") == .orderedSame) {
                    let valStr = val as? String
                    if (valStr != nil) {
                        if (valStr!.starts(with: "traceparent")) {
                            addLinkToSpan(span: span, valStr: valStr!)
                        }
                    }
                }
            }
        }
    }
    if (error != nil) {
        span.setAttribute(key: "error", value: true)
        // FIXME what else can be divined?
    }
    span.end()
}

extension URLSession {
    // FIXME repeat ad nauseum for all the public *Tasks, but also consider cases where no completion handler is provided
    
    
    @objc open func swizzled_dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        print("swizzled_dataTask")
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios", instrumentationVersion: "0.0.1")
        let span = tracer.spanBuilder(spanName: "HTTP GET").startSpan()
        // FIXME http.method, try for http.response_content_length and http.request_content_length
        span.setAttribute(key: "http.url", value: url.absoluteString)
        span.setAttribute(key: "http.method", value: "GET") // for the request: variant this will be dynamic
        return swizzled_dataTask(with: url) {(data, response, error) in
            print("got swizzled callback")
            // FIXME try/catch equiv
            completionHandler(data, response, error)
            endHttpSpan(span:span, data:data, response:response, error:error)
        }
       }
    
}

func reportExceptionSpan(e: NSException) throws {
    print(UIApplication.shared.windows[0].description)
    print(UIApplication.shared.windows[0].value(forKey: "recursiveDescription")!)
    // FIXME decide on instr name/version
    // FIXME versioning in config somewhere
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios", instrumentationVersion: "0.0.1")
    let span = tracer.spanBuilder(spanName: "UncaughtException").startSpan()
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "error.name", value: e.name.rawValue)
    if (e.reason != nil) {
        span.setAttribute(key: "error.message", value: e.reason!)
    }
    let stack = e.callStackSymbols.joined(separator: "\n")
    if (!stack.isEmpty) {
        span.setAttribute(key: "error.stack", value: stack)
    }
    
    // FIXME make instantenous, end time / EndSpanOptions (only way to do this is to pass now to start)
    span.end()
    // App likely crashing now; last-ditch effort to force-flush
    OpenTelemetrySDK.instance.tracerProvider.forceFlush()
}

var oldExceptionHandler: ((NSException) -> Void)?
func ourExceptionHandler(e: NSException) {
    print("Got an exception")
    do {
        try reportExceptionSpan(e: e)
    } catch {
        // swallow e2
    }
    if (oldExceptionHandler != nil) {
        oldExceptionHandler!(e)
    }

}

public class SplunkRum {
    static func initializeUncaughtExceptionReporting() {
        oldExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(ourExceptionHandler(e:))
    }
    static func initalizeNetworkInstrumentation() {
        // FIXME do this also to .emphemeral and results of the function .background(withIdentifier)
        // FIXME also use setImplementation and capture, rather than exchangeImpls
        let c = URLSession.self
        // This syntax is obnoxious to differentiate with:request from with:url
        let orig = class_getInstanceMethod(c, #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask))
        let swizzled = class_getInstanceMethod(c, #selector(URLSession.swizzled_dataTask(with:completionHandler:)))
        if (swizzled != nil && orig != nil) {
            method_exchangeImplementations(orig!, swizzled!)
            print("swizzled the method")
        }
    }
    
    private class func sendAppStartSpan() {
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios", instrumentationVersion: "0.0.1")
        // FIXME timestamps!
        // FIXME names for things
        let appStart = tracer.spanBuilder(spanName: "AppStart").startSpan()
        // FIXME wait this is just "iPhone" and not "iPhone 6s" or "iPhone8,1".  Why, Apple?
        appStart.setAttribute(key: "device.model", value:UIDevice.current.model)
        appStart.setAttribute(key: "os.version", value:UIDevice.current.systemVersion)
        appStart.end()
    }
    // FIXME options
    public class func initialize() {
        print("SplunkRum.initialize")
        // FIXME more Otel initialization stuff
        // FIXME need real config for zipkin, etc.
        // FIXME docload / appload!
        let options = ZipkinTraceExporterOptions(endpoint: "http://127.0.0.1:9080/api/v2/spans", serviceName: "myservice")
        let zipkin = ZipkinTraceExporter(options: options)
        OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(BatchSpanProcessor(spanExporter: zipkin))
        initializeUncaughtExceptionReporting()
        initalizeNetworkInstrumentation()
        sendAppStartSpan()

        print("SplunkRum initialization done")
    }
    public class func error(e: Any) {
        // FIXME type switch and send error.
        // Likely types to support: NSException, NSError, String, String[]
        
    }
}


