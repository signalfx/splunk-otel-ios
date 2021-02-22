import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import ZipkinExporter
import UIKit

func reportExceptionSpan(e: NSException) throws {
    print(UIApplication.shared.windows[0].description)
    print(UIApplication.shared.windows[0].value(forKey: "recursiveDescription")!)
    // FIXME decide on instr name/version
    // FIXME versioning in config somewhere
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios", instrumentationVersion: "0.0.1")
    let span = tracer.spanBuilder(spanName: "UncaughtException").startSpan()
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "error.name", value: e.name.rawValue)
    if e.reason != nil {
        span.setAttribute(key: "error.message", value: e.reason!)
    }
    let stack = e.callStackSymbols.joined(separator: "\n")
    if !stack.isEmpty {
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
    if oldExceptionHandler != nil {
        oldExceptionHandler!(e)
    }

}

class GlobalAttributesProcessor: SpanProcessor {
    var isStartRequired = true

    var isEndRequired = false

    var appName: String
    init() {
        let app = Bundle.main.infoDictionary?["CFBundleName"] as? String
        if app != nil {
            appName = app!
        } else {
            appName = "unknown-app"
        }

    }

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        span.setAttribute(key: "app", value: appName)
        addPreSpanFields(span: span)
    }

    func onEnd(span: ReadableSpan) { }
    func shutdown() { }
    func forceFlush() { }
}

/**
 Optional configuration for SplunkRum.initialize()
 */
public struct SplunkRumOptions {
    public init(allowInsecureBeacon: Bool? = false) {
        self.allowInsecureBeacon = allowInsecureBeacon
    }

    public var allowInsecureBeacon: Bool?
    // FIXME need more optional params, e.g.:
        // app (override)
        // globalAttributes
        // ignoreURLs
}

/**
 Main class for initializing the SplunkRum agent.
 */
public class SplunkRum {
    static func initializeUncaughtExceptionReporting() {
        oldExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(ourExceptionHandler(e:))
    }

    private class func sendAppStartSpan() {
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios", instrumentationVersion: "0.0.1")
        // FIXME timestamps!
        // FIXME names for things
        let appStart = tracer.spanBuilder(spanName: "AppStart").startSpan()
        // FIXME wait this is just "iPhone" and not "iPhone 6s" or "iPhone8,1".  Why, Apple?
        appStart.setAttribute(key: "device.model", value: UIDevice.current.model)
        appStart.setAttribute(key: "os.version", value: UIDevice.current.systemVersion)
        appStart.end()
    }
    // FIXME multithreading
    static var initialized = false
    static var initializing = false

    /**
            Initialization function.  Call as early as possible in your application.
                - Parameter beaconUrl: Destination for the captured data.
     
                - Parameter rumAuth: Publicly-visible `rumAuth` value.  Please do not paste any other access token or auth value into here, as this will be visible to every user of your app
                - Parameter options: Non-required configuration toggles for various features.  See SplunkRumOptions struct for details.
     
     */
    public class func initialize(beaconUrl: String, rumAuth: String, options: SplunkRumOptions? = nil) {
        if initialized || initializing {
            // FIXME error handling, logging, etc.
            print("SplunkRum already initializ{ed,ing}")
            return
        }
        initializing = true
        defer {
            initializing = false
        }
        print("SplunkRum.initialize")
        // FIXME more Otel initialization stuff
        if !beaconUrl.starts(with: "https:") && options?.allowInsecureBeacon != true {
            // FIXME error handling / API
            print("beaconUrl must be https or options: allowInsecureBeacon must be true")
            return
        }
        let options = ZipkinTraceExporterOptions(endpoint: beaconUrl+"?auth="+rumAuth, serviceName: "myservice") // FIXME control zipkin better to not emit unneeded fields
        let zipkin = ZipkinTraceExporter(options: options)
        OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(GlobalAttributesProcessor())
        OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(BatchSpanProcessor(spanExporter: zipkin))
        initializeUncaughtExceptionReporting()
        initalizeNetworkInstrumentation()
        sendAppStartSpan()
        initialized = true
        print("SplunkRum initialization done")
    }
    public class func error(e: Any) {
        // FIXME type switch and send error.
        // Likely types to support: NSException, NSError, String, String[]

    }
}
