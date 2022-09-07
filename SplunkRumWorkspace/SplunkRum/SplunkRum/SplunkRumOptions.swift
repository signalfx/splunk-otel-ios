//
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

/**
 Default maximum size of the disk cache in bytes.
 */
public let DEFAULT_DISK_CACHE_MAX_SIZE_BYTES: Int64 = 25 * 1024 * 1024

/**
 Optional configuration for SplunkRum.initialize()
 */
@objc public class SplunkRumOptions: NSObject {

    /**
        Default options
     */
    @objc public override init() {
    }
    /**
        Memberwise initializer
     */
    @objc public init(allowInsecureBeacon: Bool = false, debug: Bool = false, globalAttributes: [String: Any] = [:], environment: String? = nil, ignoreURLs: NSRegularExpression? = nil,
                      screenNameSpans: Bool = true,
                      networkInstrumentation: Bool = true,
                      enableDiskCache: Bool = false,
                      slowRenderingDetectionEnabled: Bool = true,
                      spanDiskCacheMaxSize: Int64 = DEFAULT_DISK_CACHE_MAX_SIZE_BYTES,
                      slowFrameDetectionThresholdMs: Double = 16.7,
                      frozenFrameDetectionThresholdMs: Double = 700
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
        self.slowFrameDetectionThresholdMs = slowFrameDetectionThresholdMs
        self.frozenFrameDetectionThresholdMs = frozenFrameDetectionThresholdMs
        self.slowRenderingDetectionEnabled = slowRenderingDetectionEnabled
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
       Enable the slow rendering detection feature.
     */
    @objc public var slowRenderingDetectionEnabled: Bool = true

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
