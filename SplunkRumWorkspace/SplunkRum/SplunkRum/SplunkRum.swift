import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import ZipkinExporter
import UIKit

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
    private class func processStartTime() throws -> Date {
        let name = "kern.proc.pid"
        var len: size_t = 4
        var mib = [Int32](repeating: 0, count: 4)
        var kp: kinfo_proc = kinfo_proc()
        try mib.withUnsafeMutableBufferPointer { (mibBP: inout UnsafeMutableBufferPointer<Int32>) throws in
            try name.withCString { (nbp: UnsafePointer<Int8>) throws in
                guard sysctlnametomib(nbp, mibBP.baseAddress, &len) == 0 else {
                    throw POSIXError(.EAGAIN)
                }
            }
            mibBP[3] = getpid()
            len =  MemoryLayout<kinfo_proc>.size
            guard sysctl(mibBP.baseAddress, 4, &kp, &len, nil, 0) == 0 else {
                throw POSIXError(.EAGAIN)
            }
        }
        // Type casts to finally produce the answer
        let startTime = kp.kp_proc.p_un.__p_starttime
        let ti: TimeInterval = Double(startTime.tv_sec) + (Double(startTime.tv_usec) / 1e6)
        return Date(timeIntervalSince1970: ti)
    }
    private class func sendAppStartSpan() {
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios", instrumentationVersion: "0.0.1")
        // FIXME timestamps!
        // FIXME names for things
        let appStart = tracer.spanBuilder(spanName: "AppStart").startSpan()
        // FIXME wait this is just "iPhone" and not "iPhone 6s" or "iPhone8,1".  Why, Apple?
        appStart.setAttribute(key: "device.model", value: UIDevice.current.model)
        appStart.setAttribute(key: "os.version", value: UIDevice.current.systemVersion)
        do {
            let start = try processStartTime()
            appStart.addEvent(name: "process.start", timestamp: start)
        } catch {
            // swallow
        }
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
    /**
            Convenience function for reporting an error.
     */
    public class func reportError(string: String) {
        reportStringErrorSpan(e: string)
    }
    /**
            Convenience function for reporting an error.
     */
    public class func reportError(exception: NSException) {
        reportExceptionErrorSpan(e: exception)
    }
    /**
            Convenience function for reporting an error.
     */
    public class func reportError(error: Error) {
        reportErrorErrorSpan(e: error)
    }
}
