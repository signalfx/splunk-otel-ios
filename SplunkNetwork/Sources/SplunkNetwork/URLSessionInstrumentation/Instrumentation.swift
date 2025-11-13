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

import CiscoLogger
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension
import SignPostIntegration
@_spi(SplunkInternal) import SplunkCommon

/// Used to access ignoreURLs and excludedEndpoints.
private var networkModule: NetworkInstrumentation?
private let networkModuleQueue = DispatchQueue(label: "com.splunk.networkModuleQueue")

private func getNetworkModule() -> NetworkInstrumentation? {
    networkModuleQueue.sync { networkModule }
}

private func setNetworkModule(_ module: NetworkInstrumentation?) {
    networkModuleQueue.sync {
        networkModule = module
    }
}

let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "NetworkInstrumentation")

func addLinkToSpan(span: Span, valStr: String) {

    let serverTimingPattern = #"traceparent;desc=['"]00-([0-9a-f]{32})-([0-9a-f]{16})-01['"]"#
    guard let regex = try? NSRegularExpression(pattern: serverTimingPattern) else {
        logger.log(level: .fault) {
            "Regex failed to compile"
        }

        // Intentional hard failure in both Debug and Release builds
        preconditionFailure(
            """
            Regex failed to compile. Likely programmer error in
            edit of serverTimingPattern
            regex: #\(serverTimingPattern)#
            """
        )
    }

    // Match the regex against the input string
    let result = regex.matches(in: valStr, range: NSRange(location: 0, length: valStr.utf16.count))

    // Ensure there's exactly one match and the correct number of capture groups
    guard result.count == 1, result[0].numberOfRanges == 3,
        let traceIdRange = Range(result[0].range(at: 1), in: valStr),
        let spanIdRange = Range(result[0].range(at: 2), in: valStr)
    else {
        // If the match or capture groups are invalid, log and return early
        // Also, prevent over-long log output
        let truncatedValStr = valStr.count > 255 ? String(valStr.prefix(252)) + "..." : valStr

        logger.log(level: .debug) {
            "Failed to match traceparent string: \(truncatedValStr)"
        }

        return
    }

    let traceId = String(valStr[traceIdRange])
    let spanId = String(valStr[spanIdRange])

    span.clearAndSetAttribute(key: "link.traceId", value: traceId)
    span.clearAndSetAttribute(key: "link.spanId", value: spanId)
}

func endHttpSpan(span: Span, task: URLSessionTask) {
    let hr: HTTPURLResponse? = task.response as? HTTPURLResponse
    if let hr {
        span.clearAndSetAttribute(key: "http.status_code", value: hr.statusCode)
        for (key, val) in hr.allHeaderFields {
            if let keyStr = key as? String,
                let valStr = val as? String,
                keyStr.caseInsensitiveCompare("server-timing") == .orderedSame,
                valStr.contains("traceparent")
            {
                addLinkToSpan(span: span, valStr: valStr)
            }
        }

        let length = hr.expectedContentLength
        span.clearAndSetAttribute(key: SemanticAttributes.httpResponseBodySize, value: Int(length))

        // Try to capture IP address from the response/connection
        // Update network.peer.address with actual IP if we can get it
        if let ipAddress = getIPAddressFromResponse(hr) {
            span.clearAndSetAttribute(key: "network.peer.address", value: ipAddress)
        }

        let protocolVersion = determineHTTPProtocolVersion(hr)
        span.clearAndSetAttribute(key: "http.protocol.version", value: protocolVersion)
    }

    if let error = task.error {
        span.clearAndSetAttribute(key: "error", value: true)
        span.clearAndSetAttribute(key: "error.message", value: error.localizedDescription)
        span.clearAndSetAttribute(key: "error.type", value: String(describing: type(of: error)))

        logger.log(level: .error) {
            "Error: \(error.localizedDescription)"
        }
    }

    span.clearAndSetAttribute(key: "http.response_content_length_uncompressed", value: Int(task.countOfBytesReceived))
    if task.countOfBytesSent != 0 {
        span.clearAndSetAttribute(key: "http.request_content_length", value: Int(task.countOfBytesSent))
    }
    span.end()
}

func determineHTTPProtocolVersion(_ response: HTTPURLResponse) -> String {
    // Check for HTTP/2 server indicators
    if let serverHeader = response.value(forHTTPHeaderField: "Server") {
        if serverHeader.lowercased().contains("http/2") || serverHeader.lowercased().contains("h2") {
            return "2.0"
        }
    }

    // Check for HTTP/2 specific headers
    if response.value(forHTTPHeaderField: "X-Firefox-Spdy") != nil || response.value(forHTTPHeaderField: "X-Google-Spdy") != nil {
        return "2.0"
    }
    return "1.1"
}

func getIPAddressFromResponse(_ response: HTTPURLResponse) -> String? {
    // Some proxies or load balancers add headers with IP information
    if let forwardedFor = response.value(forHTTPHeaderField: "X-Forwarded-For") {
        // X-Forwarded-For can contain multiple IPs, take the first one
        let ips = forwardedFor.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if let firstIP = ips.first, isValidIPAddress(firstIP) {
            return firstIP
        }
    }
    if let realIP = response.value(forHTTPHeaderField: "X-Real-IP") {
        if isValidIPAddress(realIP) {
            return realIP
        }
    }
    return nil
}

func isValidIPAddress(_ ipString: String) -> Bool {
    var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))

    // Try IPv4 validation using inet_pton
    if inet_pton(AF_INET, ipString, &buffer) == 1 {
        return true
    }

    // Try IPv6 validation using inet_pton
    if inet_pton(AF_INET6, ipString, &buffer) == 1 {
        return true
    }

    return false
}

func isSupportedTask(task: URLSessionTask) -> Bool {
    task is URLSessionDataTask || task is URLSessionDownloadTask || task is URLSessionUploadTask
}

/// Checks if a URL should be excluded based on the excluded endpoints list.
///
/// Uses precise URL matching by comparing scheme, host, and path prefix to avoid false positives.
func shouldExcludeURL(_ url: URL, excludedEndpoints: [URL]) -> Bool {

    for excludedEndpoint in excludedEndpoints {
        // Match scheme (both must be http or https, or exact match)
        let requestScheme = url.scheme?.lowercased() ?? ""
        let excludedScheme = excludedEndpoint.scheme?.lowercased() ?? ""
        guard requestScheme == excludedScheme else {
            continue
        }

        // Match host (exact match)
        let requestHost = url.host?.lowercased() ?? ""
        let excludedHost = excludedEndpoint.host?.lowercased() ?? ""
        guard requestHost == excludedHost else {
            continue
        }

        // Match port (if specified in excluded endpoint)
        if let excludedPort = excludedEndpoint.port {
            let requestPort = url.port ?? (requestScheme == "https" ? 443 : 80)
            guard requestPort == excludedPort else {
                continue
            }
        }

        // Match path (excluded endpoint path must be a prefix of request path)
        let requestPath = url.path
        let excludedPath = excludedEndpoint.path
        if excludedPath.isEmpty || excludedPath == "/" {
            // If excluded path is empty or "/", match any path on this host
            return true
        }
        if requestPath.hasPrefix(excludedPath) {
            return true
        }
    }
    return false
}

func startHttpSpan(request: URLRequest?) -> Span? {
    guard let request, let url = request.url else {
        return nil
    }

    if !(url.scheme?.lowercased().starts(with: "http") ?? false) {
        return nil
    }
    let method = request.httpMethod ?? "_OTHER"
    let body = request.httpBody
    let length = body?.count ?? 0
    let excludedEndpoints = getNetworkModule()?.excludedEndpoints
    guard let excludedEndpoints else {
        logger.log(level: .debug) {
            "Should Not Instrument, Backend URL not yet configured."
        }
        return nil
    }

    if shouldExcludeURL(url, excludedEndpoints: excludedEndpoints) {
        logger.log(level: .debug) {
            "Should Not Instrument Backend URL \(url.absoluteString)"
        }
        return nil
    }

    // Filter using ignoreURLs API
    if let ignoreURLs = getNetworkModule()?.getIgnoreURLs() {
        if ignoreURLs.matches(url: url) {
            logger.log(level: .debug) {
                "URL excluded via IgnoreURLs API \(url.absoluteString)"
            }
            return nil
        }
    }

    let tracer = OpenTelemetry.instance
        .tracerProvider
        .get(
            instrumentationName: "NetworkInstrumentation",
            instrumentationVersion: getNetworkModule()?.sharedState?.agentVersion
        )

    let span = tracer.spanBuilder(spanName: "HTTP " + method)
        .setStartTime(time: Date())
        .startSpan()

    addDataToSpan(url: url, method: method, length: length, span: span)

    return span
}

func addDataToSpan(url: URL, method: String, length: Int, span: Span) {
    span.clearAndSetAttribute(key: SemanticAttributes.httpRequestBodySize, value: length)
    span.clearAndSetAttribute(key: SemanticAttributes.httpRequestMethod, value: method)
    span.clearAndSetAttribute(key: "component", value: "http")

    span.clearAndSetAttribute(key: SemanticAttributes.urlPath, value: url.path)
    span.clearAndSetAttribute(key: SemanticAttributes.urlQuery, value: url.query ?? "")
    if let scheme = url.scheme {
        span.clearAndSetAttribute(key: SemanticAttributes.urlScheme, value: scheme)
    }

    if let host = url.host {
        span.clearAndSetAttribute(key: "server.address", value: host)
        // Preload with host in case IP cannot be determined
        span.clearAndSetAttribute(key: "network.peer.address", value: host)
    }

    if let port = url.port {
        span.clearAndSetAttribute(key: "network.peer.port", value: port)
    }
    else {
        let defaultPort = url.scheme?.lowercased() == "https" ? 443 : 80
        span.clearAndSetAttribute(key: "network.peer.port", value: defaultPort)
    }

    if let scheme = url.scheme?.lowercased() {
        span.clearAndSetAttribute(key: "network.protocol.name", value: scheme)
    }

    span.clearAndSetAttribute(key: "url.full", value: url.absoluteString)

    if let sharedState = getNetworkModule()?.sharedState {
        let sessionID: String = sharedState.sessionId
        span.clearAndSetAttribute(key: "session.id", value: sessionID)
    }
}

private var assocKeySpan: UInt8 = 0

extension URLSessionTask {
    @objc
    open func splunkSwizzledSetState(state: URLSessionTask.State) {
        defer {
            splunkSwizzledSetState(state: state)
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
        guard let span = objc_getAssociatedObject(self, &assocKeySpan) as? Span else {
            return
        }

        endHttpSpan(span: span, task: self)
    }

    @objc
    open func splunkSwizzledResume() {
        defer {
            splunkSwizzledResume()
        }
        if !isSupportedTask(task: self) {
            return
        }
        if state == URLSessionTask.State.completed || state == URLSessionTask.State.canceling {
            return
        }
        let existingSpan: Span? = objc_getAssociatedObject(self, &assocKeySpan) as? Span
        if existingSpan != nil {
            return
        }
        startHttpSpan(request: currentRequest)
            .map { span in
                objc_setAssociatedObject(self, &assocKeySpan, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            }
    }
}

func swizzle(clazz: AnyClass, orig: Selector, swizzled: Selector) {
    let origM = class_getInstanceMethod(clazz, orig)
    let swizM = class_getInstanceMethod(clazz, swizzled)
    if let origM, let swizM {
        method_exchangeImplementations(origM, swizM)
    }
    else {
        logger.log(level: .fault) {
            "could not swizzle \(NSStringFromSelector(orig))"
        }
    }
}

func swizzledUrlSessionClasses() -> [AnyClass] {
    let conf = URLSessionConfiguration.ephemeral
    let session = URLSession(configuration: conf)
    guard let url = URL(string: "https://splunkrum") else {
        return []
    }

    let localDataTask = session.dataTask(with: url)

    defer {
        localDataTask.cancel()
        session.finishTasksAndInvalidate()
    }

    let setStateSelector = NSSelectorFromString("setState:")
    var classes: [AnyClass] = []
    guard var currentClass: AnyClass = object_getClass(localDataTask) else {
        return classes
    }

    var method = class_getInstanceMethod(currentClass, setStateSelector)
    while let currentMethod = method {
        let classResumeImp = method_getImplementation(currentMethod)
        let superClass: AnyClass? = currentClass.superclass()
        let superClassMethod = class_getInstanceMethod(superClass, setStateSelector)
        let superClassResumeImp = superClassMethod.map { method_getImplementation($0) }

        if classResumeImp != superClassResumeImp {
            classes.append(currentClass)
        }

        guard let nextClass = superClass else {
            return classes
        }

        currentClass = nextClass
        method = superClassMethod
    }
    return classes
}

func swizzleUrlSession() {
    let classes = swizzledUrlSessionClasses()

    let setStateSelector = NSSelectorFromString("setState:")
    let resumeSelector = NSSelectorFromString("resume")

    for classToSwizzle in classes {
        swizzle(clazz: classToSwizzle, orig: setStateSelector, swizzled: #selector(URLSessionTask.splunkSwizzledSetState(state:)))
        swizzle(clazz: classToSwizzle, orig: resumeSelector, swizzled: #selector(URLSessionTask.splunkSwizzledResume))
    }
}

/// Ensures swizzling only happens once, even if initializeNetworkInstrumentation is called multiple times.
private let swizzleOnce: Void = {
    swizzleUrlSession()
}()

func initializeNetworkInstrumentation(module: NetworkInstrumentation) {
    _ = swizzleOnce
    setNetworkModule(module)
}
