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

// swiftlint:disable file_length
import Foundation
import WebKit

// Make sure the version numbers on the podspec and SplunkRum.swift match
let SplunkRumVersionString = "0.11.2"

/**
 Default maximum size of the disk cache in bytes.
 */
public let DEFAULT_DISK_CACHE_MAX_SIZE_BYTES: Int64 = 25 * 1024 * 1024

/**
 Optional configuration for SplunkRum.initialize()
 */
@objc class SplunkRumOptions: NSObject {

    /**
        Default options
     */
    @objc public override init() {
    }
    /**
        Memberwise initializer
     */
    @objc public init(allowInsecureBeacon: Bool = false,
                      debug: Bool = false,
                      globalAttributes: [String: Any] = [:],
                      environment: String? = nil,
                      ignoreURLs: NSRegularExpression? = nil,
                      screenNameSpans: Bool = true,
                      networkInstrumentation: Bool = true,
                      enableDiskCache: Bool = false,
                      spanDiskCacheMaxSize: Int64 = DEFAULT_DISK_CACHE_MAX_SIZE_BYTES,
                      slowRenderingDetectionEnabled: Bool = true,
                      slowFrameDetectionThresholdMs: Double = 16.7,
                      frozenFrameDetectionThresholdMs: Double = 700,
                      sessionSamplingRatio: Double = 1.0,
                      spanSchedulingDelay: TimeInterval = 5.0
    ) {
        // rejectionFilter not specified to make it possible to call from objc
        self.allowInsecureBeacon = allowInsecureBeacon
        self.debug = debug
        self.globalAttributes = globalAttributes
        self.environment = environment
        self.ignoreURLs = ignoreURLs
        self.screenNameSpans = screenNameSpans
        self.networkInstrumentation = networkInstrumentation
        self.enableDiskCache = enableDiskCache
        self.spanDiskCacheMaxSize = spanDiskCacheMaxSize
        self.slowRenderingDetectionEnabled = slowRenderingDetectionEnabled
        self.slowFrameDetectionThresholdMs = slowFrameDetectionThresholdMs
        self.frozenFrameDetectionThresholdMs = frozenFrameDetectionThresholdMs
        self.sessionSamplingRatio = sessionSamplingRatio
    }
    /**
        Copy constructor
     */
    @objc public init(opts: SplunkRumOptions) {
        self.allowInsecureBeacon = opts.allowInsecureBeacon
        self.debug = opts.debug
        // shallow copy of the map
        self.globalAttributes = [:].merging(opts.globalAttributes) { _, new in new }
        self.environment = opts.environment
        self.ignoreURLs = opts.ignoreURLs
        self.spanFilter = opts.spanFilter
        self.showVCInstrumentation = opts.showVCInstrumentation
        self.screenNameSpans = opts.screenNameSpans
        self.slowRenderingDetectionEnabled = opts.slowRenderingDetectionEnabled
        self.slowFrameDetectionThresholdMs = opts.slowFrameDetectionThresholdMs
        self.frozenFrameDetectionThresholdMs = opts.frozenFrameDetectionThresholdMs
        self.networkInstrumentation = opts.networkInstrumentation
        self.enableDiskCache = opts.enableDiskCache
        self.spanDiskCacheMaxSize = opts.spanDiskCacheMaxSize
        self.sessionSamplingRatio = opts.sessionSamplingRatio
        self.bspScheduleDelay = opts.bspScheduleDelay
    }

    /**
            Allows non-https beaconUrls.  Default: false
     */
    @objc public var allowInsecureBeacon: Bool = false
    /**
            Turns on debug logging (including printouts of all spans)  Default: false
     */
    @objc public var debug: Bool = false
    /**
                    Specifies additional attributes to add to every span.  Acceptable value types are Int, Double, String, and Bool.  Other value types will be silently ignored
     */
    @objc public var globalAttributes: [String: Any] = [:]

    /**
        Sets a value for the "environment" global attribute
     */
    @objc public var environment: String?

    /**
     Do not create spans for HTTP requests whose URL matches this regex.
     */
    @objc public var ignoreURLs: NSRegularExpression?

    /**
    Sets a filter that can modify or reject spans.  You can modify attributes of each span or return nil to indicate that that span should be dropped (never sent on the wire).
    */
    public var spanFilter: ((SpanData) -> SpanData?)?

    /**
     Enable span creation for ViewController Show events.
     */
    @objc public var showVCInstrumentation: Bool = true

    /**
     Enable span creation for screen name changes
     */
    @objc public var screenNameSpans: Bool = true

    /**
     Enable NetworkInstrumentation span creation for https calls.
     */
    @objc public var networkInstrumentation: Bool = true

    /**
     Enable slow rendering detection. Slow rendering detection generates spans whenever it detects a slow or frozen frame render.
     */
    @objc public var slowRenderingDetectionEnabled: Bool = true

    /**
     Threshold, in milliseconds, from which to count a rendered frame as slow.
    */
    @objc public var slowFrameDetectionThresholdMs: Double = 16.7

    /**
     Threshold, in milliseconds, from which to count a rendered frame as frozen.
    */
    @objc public var frozenFrameDetectionThresholdMs: Double = 700

    /**
     Enable caching created spans to disk. On successful exports the spans are deleted.
     */
    @objc public var enableDiskCache: Bool = false

    /**
     Threshold in bytes from which spans will start to be dropped from the disk cache (oldest first).
     Only applicable when disk caching is enabled.
     */
    @objc public var spanDiskCacheMaxSize: Int64 = DEFAULT_DISK_CACHE_MAX_SIZE_BYTES

    /**
    Percentage of sessions to send spans / data.
     */
    @objc public var sessionSamplingRatio: Double = 1.0

    /**
     Set the maximum interval between 2 consecutive span exports
     */
    @objc public var bspScheduleDelay: TimeInterval = 5.0

    func toAttributeValue() -> String {
        var answer = "debug: "+debug.description
        if spanFilter != nil {
            answer += ", spanFilter: set"
        }
        if ignoreURLs != nil {
            answer += ", ignoreUrls: "+ignoreURLs!.description
        }
        if !showVCInstrumentation {
            answer += ", showVC: false"
        }
        if !screenNameSpans {
            answer += ", screenNameSpans: false"
        }
        return answer
    }

}

var globalAttributes: [String: Any] = [:]
let globalAttributesLock = NSLock()

let splunkLibraryLoadTime = Date()
var splunkRumInitializeCalledTime = Date()

// Disable swiftlint body length check on this class.  Remove once the initialize function is removed.
// swiftlint:disable type_body_length
/**
 Main class for initializing the SplunkRum agent.
 */
@objc public class SplunkRum: NSObject {
    static var initialized = false
    static var initializing = false
    static var configuredOptions: SplunkRumOptions?
    static var theBeaconUrl: String?

    /**
            Initialization function.  Call as early as possible in your application, but only on the main thread.
                - Parameter beaconUrl: Destination for the captured data.
     
                - Parameter rumAuth: Publicly-visible `rumAuth` value.  Please do not paste any other access token or auth value into here, as this will be visible to every user of your app
                - Parameter options: Non-required configuration toggles for various features.  See SplunkRumOptions struct for details.
     
     */
    @available(*, deprecated, message: "This method of initializing SplunkRum will be removed in a later version.  Use SplunkRumBuilder to initialize SplunkRum going forward.")
    @discardableResult
    @objc class func initialize(beaconUrl: String, rumAuth: String, options: SplunkRumOptions? = nil) -> Bool {
        if !Thread.isMainThread {
            print("SplunkRum: Please call SplunkRum.initialize only on the main thread")
            return false
        }
        if initialized || initializing {
            debug_log("SplunkRum already initializ{ed,ing}")
            return false
        }

        if !beaconUrl.starts(with: "https:") && options?.allowInsecureBeacon != true {
            print("SplunkRum: beaconUrl must be https or options: allowInsecureBeacon must be true")
            return false
        }

        splunkRumInitializeCalledTime = Date()
        initializing = true
        defer {
            initializing = false
        }
        debug_log("SplunkRum.initialize")

        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: GlobalAttributesProcessor())
            .with(sampler: SessionBasedSampler(ratio: options?.sessionSamplingRatio ?? 1.0))
            .build()

        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

        if options != nil {
            configuredOptions = SplunkRumOptions(opts: options!)
        }
        if options?.globalAttributes != nil {
            setGlobalAttributes(options!.globalAttributes)
        }
        if options?.environment != nil {
            setGlobalAttributes(["environment": options!.environment!])
        }

        if rumAuth.isEmpty {
            theBeaconUrl = beaconUrl
        } else {
            theBeaconUrl = beaconUrl + "?auth="+rumAuth
        }

        if options?.enableDiskCache ?? false {
            let spanDb = SpanDb()
            SpanFromDiskExport.start(spanDb: spanDb, endpoint: theBeaconUrl!)
            let diskExporter = SpanToDiskExporter(
                spanDb: spanDb,
                maxFileSizeBytes: options?.spanDiskCacheMaxSize ?? DEFAULT_DISK_CACHE_MAX_SIZE_BYTES)
            let limiting = LimitingExporter(proxy: diskExporter, spanFilter: options?.spanFilter ?? nil)
            let delay = options?.bspScheduleDelay ?? 5.0
            tracerProvider.addSpanProcessor(BatchSpanProcessor(spanExporter: limiting,
                                                               scheduleDelay: delay))
        } else {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                SpanDb.deleteAtDefaultLocation()
            }
            let exportOptions = ZipkinTraceExporterOptions(endpoint: theBeaconUrl!, serviceName: "myservice") // FIXME control zipkin better to not emit unneeded fields
            let zipkin = ZipkinTraceExporter(options: exportOptions)
            let retry = RetryExporter(proxy: zipkin)
            let limiting = LimitingExporter(proxy: retry, spanFilter: options?.spanFilter ?? nil)
            let delay = options?.bspScheduleDelay ?? 5.0
            tracerProvider.addSpanProcessor(BatchSpanProcessor(spanExporter: limiting,
                                                               scheduleDelay: delay))
        }

        if options?.debug ?? false {
            tracerProvider.addSpanProcessor(SimpleSpanProcessor(spanExporter: StdoutExporter(isDebug: true)))
        }
        sendAppStartSpan()
        let srInit = buildTracer()
            .spanBuilder(spanName: Constants.SpanNames.SPLUNK_RUM_INITIALIZE)
            .setStartTime(time: splunkRumInitializeCalledTime)
            .startSpan()
        srInit.setAttribute(key: Constants.AttributeNames.COMPONENT, value: "appstart")
        if options != nil {
            srInit.setAttribute(key: Constants.AttributeNames.CONFIG_SETTINGS, value: options!.toAttributeValue())
        }
        if options?.networkInstrumentation ?? true {
            initalizeNetworkInstrumentation()
        }
        initializeNetworkTypeMonitoring()
        initalizeUIInstrumentation()
        if options?.slowRenderingDetectionEnabled ?? true {
            startSlowFrameDetector(
                slowFrameDetectionThresholdMs: options?.slowFrameDetectionThresholdMs,
                frozenFrameDetectionThresholdMs: options?.frozenFrameDetectionThresholdMs
            )
        }
        // not initializeAppLifecycleInstrumentation, done at end of AppStart
        srInit.end()
        initialized = true
        print("SplunkRum.initialize() complete")
        return true
    }

    @discardableResult
    @objc internal class func create(beaconUrl: String, rumAuth: String, appName: String?, options: SplunkRumOptions) -> Bool {
        guard Thread.isMainThread else {
            print("SplunkRum: Please call SplunkRum.create only on the main thread")
            return false
        }
        if initialized || initializing {
            debug_log("SplunkRum already create{ed,ing}")
            return false
        }
        guard beaconUrl.starts(with: "https:") || options.allowInsecureBeacon else {
            print("SplunkRum: beaconUrl must be https or options: allowInsecureBeacon must be true")
            return false
        }

        splunkRumInitializeCalledTime = Date()
        initializing = true
        defer {
            initializing = false
        }
        debug_log("SplunkRum.create")

        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: GlobalAttributesProcessor(appName: appName))
            .with(sampler: SessionBasedSampler(ratio: options.sessionSamplingRatio))
            .build()

        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

        configuredOptions = SplunkRumOptions(opts: options)
        setGlobalAttributes(options.globalAttributes)
        if let environment = options.environment {
            setGlobalAttributes(["environment": environment])
        }

        if rumAuth.isEmpty {
            theBeaconUrl = beaconUrl
        } else {
            theBeaconUrl = beaconUrl + "?auth="+rumAuth
        }

        if options.enableDiskCache {
            let spanDb = SpanDb()
            SpanFromDiskExport.start(spanDb: spanDb, endpoint: theBeaconUrl!)
            let diskExporter = SpanToDiskExporter(
                spanDb: spanDb,
                maxFileSizeBytes: options.spanDiskCacheMaxSize)
            let limiting = LimitingExporter(proxy: diskExporter, spanFilter: options.spanFilter)
            let delay = options.bspScheduleDelay
            tracerProvider.addSpanProcessor(BatchSpanProcessor(spanExporter: limiting,
                                                              scheduleDelay: delay))
        } else {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                SpanDb.deleteAtDefaultLocation()
            }
            let exportOptions = ZipkinTraceExporterOptions(endpoint: theBeaconUrl!, serviceName: "myservice") // FIXME control zipkin better to not emit unneeded fields
            let zipkin = ZipkinTraceExporter(options: exportOptions)
            let retry = RetryExporter(proxy: zipkin)
            let limiting = LimitingExporter(proxy: retry, spanFilter: options.spanFilter)
            let delay = options.bspScheduleDelay
            tracerProvider.addSpanProcessor(BatchSpanProcessor(spanExporter: limiting,
                                                              scheduleDelay: delay))
        }

        if options.debug {
            tracerProvider.addSpanProcessor(SimpleSpanProcessor(spanExporter: StdoutExporter(isDebug: true)))
        }
        sendAppStartSpan()
        let srInit = buildTracer()
            .spanBuilder(spanName: Constants.SpanNames.SPLUNK_RUM_INITIALIZE)
            .setStartTime(time: splunkRumInitializeCalledTime)
            .startSpan()
        srInit.setAttribute(key: Constants.AttributeNames.COMPONENT, value: "appstart")
        srInit.setAttribute(key: Constants.AttributeNames.CONFIG_SETTINGS, value: options.toAttributeValue())
        if options.networkInstrumentation {
            initalizeNetworkInstrumentation()
        }
        initializeNetworkTypeMonitoring()
        initalizeUIInstrumentation()
        if options.slowRenderingDetectionEnabled {
            startSlowFrameDetector(
                slowFrameDetectionThresholdMs: options.slowFrameDetectionThresholdMs,
                frozenFrameDetectionThresholdMs: options.frozenFrameDetectionThresholdMs
            )
        }
        // not initializeAppLifecycleInstrumentation, done at end of AppStart
        srInit.end()
        initialized = true
        print("SplunkRum.create() complete")
        return true

    }

    /**
            Query for the current session ID.  Session IDs can change during the usage of the app so caching this result is not advised.
     */
    @objc public class func getSessionId() -> String {
        return getRumSessionId()
    }
    /**
     Adds a callback whenever the sessionId changes.
     */
    public class func addSessionIdChangeCallback(_ callback: @escaping (() -> Void)) {
        addSessionIdCallback(callback)
    }
    /**
     Adds a callback whenever the screen name changes.
     */
    public class func addScreenNameChangeCallback(_ callback: @escaping ((String) -> Void)) {
        addScreenNameCallback(callback)
    }
    /**
            Convenience function for reporting an error.
     */
    @objc public class func reportError(string: String) {
        reportStringErrorSpan(e: string)
    }
    /**
            Convenience function for reporting an error.
     */
    @objc public class func reportError(exception: NSException) {
        reportExceptionErrorSpan(e: exception)
    }
    /**
            Convenience function for reporting an error.
     */
    @objc public class func reportError(error: Error) {
        reportErrorErrorSpan(e: error)
    }
    /**
            Convenience function for reporting an event.
     */
    @objc public class func reportEvent(name: String, attributes: NSDictionary) {
        let tracer = buildTracer()
        let now = Date()
        let span = tracer.spanBuilder(spanName: name)
        for attribute in attributes {
            span.setAttribute(key: attribute.key as? String ?? "", value: AttributeValue(attribute.value) ?? AttributeValue("")!)
        }
        span.setStartTime(time: now).startSpan().end(time: now)
    }

    // Threading strategy for globalAttributes is to hold lock and commit unchanging
    // (after lock release) objects to the global reference.  Span iterators will get
    // some self-consistent snapshot while modifications can take place "concurrently".

    /**
        Set or override  one or more global attributes; acceptable types are Int, Double, String, and Bool.  Other value types will be silently ignored.  Can only be called after SplunkRum.initialize()
     */
    @objc public class func setGlobalAttributes(_ attributes: [String: Any]) {
        globalAttributesLock.lock()
        defer {
            globalAttributesLock.unlock()
        }
        let newAttrs = globalAttributes.merging(attributes) { (_, new) in
            return new
        }
        globalAttributes = newAttrs
    }
    /**
            Remove the global attribute with the specified key
     */
    @objc public class func removeGlobalAttribute(_ key: String) {
        globalAttributesLock.lock()
        defer {
            globalAttributesLock.unlock()
        }
        var newAttrs = [:].merging(globalAttributes) { _, new in new }
        newAttrs.removeValue(forKey: key)
        globalAttributes = newAttrs
    }

    /*non-public*/ class func internalGetGlobalAttributes() -> [String: Any] {
        globalAttributesLock.lock()
        defer {
            globalAttributesLock.unlock()
        }
        return globalAttributes
    }

    /*non-public*/ class func addGlobalAttributesToSpan(_ span: Span) {
        let attrs = internalGetGlobalAttributes()
        attrs.forEach({ (key: String, value: Any) in
            switch value {
            case is Int:
                span.setAttribute(key: key, value: value as! Int)
            case is String:
                span.setAttribute(key: key, value: value as! String)
            case is Double:
                span.setAttribute(key: key, value: value as! Double)
            case is Bool:
                span.setAttribute(key: key, value: value as! Bool)
            default:
                nop()
            }
        })

    }
        /**
            Specifies a better screen.name value.
     
     **CAUTION** - if you use this API, you must use it everywhere;
        specifying any screen name manually will cause our automatic name choice (based on ViewController type name) to never be used again. In other words, if you use this once, you need to think through all the places where you'd like the screen name to be changed.
     
            
     **This must be called from the main thread**.  Other usage will fail with a printed warning message in debug mode
     
     */
    @objc public class func setScreenName(_ name: String) {
        if !Thread.current.isMainThread {
            debug_log("SplunkRum.setScreenName not called from main thread: "+Thread.current.debugDescription)
            return
        }
        internal_setScreenName(name, true)
    }

    /**
        For debugging purposes; only has an effect if debug=true in configuration
     */
    public class func debugLog(_ msg: String) {
        debug_log(msg)
    }

    /**
     Adds a window-level object to the WebKit WKWebView that allows browser SplunkRum to
     see the native app's splunk.rumSessionId.  This allows us to integrate the data streams from the two
     products.  Note that this exposes the (splunk) session ID to any page loaded through this view - it should
     probably only be used for views which are definitely going to be instrumented by apps under your control, and not
     ones that allow general browsing.  You should call this after the WKWebView is initialized but before it is
     actually used.
     */
    @objc public class func integrateWithBrowserRum(_ view: WKWebView) {
        integrateWebViewWithBrowserRum(view: view)
    }

    /**
       This check is to determine whether the splunkrum library has been initialized
     */
    @objc public class func isInitialized() -> Bool {
        return initialized
    }

    /**
        Updates the current location. The latitude and longitude will be appended to every span and event.
    */
    @objc public class func setLocation(latitude: Double, longitude: Double) {
        setGlobalAttributes(["location.lat": latitude, "location.long": longitude])
    }
}
// swiftlint:enable type_body_length
