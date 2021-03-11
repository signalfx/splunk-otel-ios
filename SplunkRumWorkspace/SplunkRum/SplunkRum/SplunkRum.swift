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
import OpenTelemetrySdk
import ZipkinExporter
import StdoutExporter
import UIKit

/**
 Optional configuration for SplunkRum.initialize()
 */
public struct SplunkRumOptions {
    public init(allowInsecureBeacon: Bool? = false, enableCrashReporting: Bool? = true, debug: Bool? = false, globalAttributes: [String: Any]? = nil) {
        self.allowInsecureBeacon = allowInsecureBeacon
        self.enableCrashReporting = enableCrashReporting
        self.debug = debug
        self.globalAttributes = globalAttributes
    }
    /**
            Allows non-https beaconUrls.  Default: false
     */
    public var allowInsecureBeacon: Bool?
    /**
                    Turns on the crash reporting with PLCrashReporter feature.  Default: true
     */
    public var enableCrashReporting: Bool?
    /**
            Turns on debug logging (including printouts of all spans)  Default: false
     */
    public var debug: Bool?
    /**
                    Specifies additional attributes to add to every span.  Acceptable value types are Int, Double, String, and Bool.  Other value types will be silently ignored
     */
    public var globalAttributes: [String: Any]?

    // FIXME ignoreURLs for http spans
}

/**
 Main class for initializing the SplunkRum agent.
 */
public class SplunkRum {
    // FIXME multithreading
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
    public class func initialize(beaconUrl: String, rumAuth: String, options: SplunkRumOptions? = nil) {
        if !Thread.isMainThread {
            print("SplunkRum: Please call SplunkRum.initialize only on the main thread")
            return
        }
        if initialized || initializing {
            debug_log("SplunkRum already initializ{ed,ing}")
            return
        }
        initializing = true
        defer {
            initializing = false
        }
        debug_log("SplunkRum.initialize")
        configuredOptions = options
        // FIXME apply global attribute length cap
        if !beaconUrl.starts(with: "https:") && options?.allowInsecureBeacon != true {
            print("SplunkRum: beaconUrl must be https or options: allowInsecureBeacon must be true")
            return
        }
        theBeaconUrl = beaconUrl
        let exportOptions = ZipkinTraceExporterOptions(endpoint: beaconUrl+"?auth="+rumAuth, serviceName: "myservice") // FIXME control zipkin better to not emit unneeded fields
        let zipkin = ZipkinTraceExporter(options: exportOptions)
        OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(GlobalAttributesProcessor(options?.globalAttributes ?? nil))
        OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(BatchSpanProcessor(spanExporter: LimitingExporter(proxy: zipkin)))
        if options?.debug ?? false {
            OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(SimpleSpanProcessor(spanExporter: StdoutExporter(isDebug: true)))
        }
        sendAppStartSpan()
        initalizeNetworkInstrumentation()
        initalizeUIInstrumentation()
        if options?.enableCrashReporting ?? true {
            initializeCrashReporting()
        }
        initialized = true
        print("SplunkRum.initialize() complete")
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
