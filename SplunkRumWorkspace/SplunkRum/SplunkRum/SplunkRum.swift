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
import UIKit

class GlobalAttributesProcessor: SpanProcessor {
    var isStartRequired = true

    var isEndRequired = false

    var appName: String
    var appVersion: String?
    init() {
        let app = Bundle.main.infoDictionary?["CFBundleName"] as? String
        if app != nil {
            appName = app!
        } else {
            appName = "unknown-app"
        }
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    }

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        span.setAttribute(key: "app", value: appName)
        if appVersion != nil {
            span.setAttribute(key: "app.verson", value: appVersion!)
        }
        span.setAttribute(key: "splunk.rumSessionId", value: getRumSessionId())
        span.setAttribute(key: "splunk.rumVersion", value: SplunkRumVersionString)
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
    // FIXME multithreading
    static var initialized = false
    static var initializing = false
    static var theBeaconUrl: String?

    /**
            Initialization function.  Call as early as possible in your application, but only on the main thread.
                - Parameter beaconUrl: Destination for the captured data.
     
                - Parameter rumAuth: Publicly-visible `rumAuth` value.  Please do not paste any other access token or auth value into here, as this will be visible to every user of your app
                - Parameter options: Non-required configuration toggles for various features.  See SplunkRumOptions struct for details.
     
     */
    public class func initialize(beaconUrl: String, rumAuth: String, options: SplunkRumOptions? = nil) {
        if !Thread.isMainThread {
            print("Please call SplunkRum.initialize only on the main thread")
            return
        }
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
        theBeaconUrl = beaconUrl
        let options = ZipkinTraceExporterOptions(endpoint: beaconUrl+"?auth="+rumAuth, serviceName: "myservice") // FIXME control zipkin better to not emit unneeded fields
        let zipkin = ZipkinTraceExporter(options: options)
        OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(GlobalAttributesProcessor())
        OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(BatchSpanProcessor(spanExporter: zipkin))
        initializeUncaughtExceptionReporting()
        initalizeNetworkInstrumentation()
        initalizeUIInstrumentation()
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
        reportExceptionErrorSpan(e: exception, manuallyReported: true)
    }
    /**
            Convenience function for reporting an error.
     */
    public class func reportError(error: Error) {
        reportErrorErrorSpan(e: error)
    }
}
