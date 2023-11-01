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

@objc public class SplunkRumBuilder: NSObject {

    private var beaconUrl: String
    private var rumAuth: String
    private var allowInsecureBeacon: Bool = false
    private var debug: Bool = false
    private var globalAttributes: [String: Any] = [:]
    private var environment: String?
    private var ignoreURLs: NSRegularExpression?
    private var screenNameSpans: Bool = true
    private var networkInstrumentation: Bool = true
    private var enableDiskCache: Bool = false
    private var spanDiskCacheMaxSize: Int64 = DEFAULT_DISK_CACHE_MAX_SIZE_BYTES
    private var slowRenderingDetectionEnabled: Bool = true
    private var slowFrameDetectionThresholdMs: Double = 16.7
    private var frozenFrameDetectionThresholdMs: Double = 700
    private var sessionSamplingRatio: Double = 1.0
    private var appName: String?
    private var spanSchedulingDelay: TimeInterval = 5.0
    private var showVCInstrumentation: Bool = true

    @objc public init(beaconUrl: String, rumAuth: String) {
        self.beaconUrl = beaconUrl
        self.rumAuth = rumAuth
    }

    @objc public init(realm: String, rumAuth: String) {
        self.beaconUrl = "https://rum-ingest.\(realm).signalfx.com/v1/rum"
        self.rumAuth = rumAuth
    }

    @discardableResult
    @objc
    public func allowInsecureBeacon(enabled: Bool) -> SplunkRumBuilder {
        self.allowInsecureBeacon = enabled
        return self
    }

    @discardableResult
    @objc
    public func debug(enabled: Bool) -> SplunkRumBuilder {
        self.debug = enabled
        return self
    }

    @discardableResult
    @objc
    public func globalAttributes(globalAttributes: [String: Any]) -> SplunkRumBuilder {
        self.globalAttributes = globalAttributes
        return self
    }

    @discardableResult
    @objc
    public func deploymentEnvironment(environment: String) -> SplunkRumBuilder {
        self.environment = environment
        return self
    }

    @discardableResult
    @objc
    public func ignoreURLs(ignoreURLs: NSRegularExpression) -> SplunkRumBuilder {
        self.ignoreURLs = ignoreURLs
        return self
    }

    @discardableResult
    @objc
    public func showVCInstrumentation(_ show: Bool) -> SplunkRumBuilder {
        self.showVCInstrumentation = show
        return self
    }

    @discardableResult
    @objc
    public func screenNameSpans(enabled: Bool) -> SplunkRumBuilder {
        self.screenNameSpans = enabled
        return self
    }

    @discardableResult
    @objc
    public func networkInstrumentation(enabled: Bool) -> SplunkRumBuilder {
        self.networkInstrumentation = enabled
        return self
    }

    @discardableResult
    @objc
    public func enableDiskCache(enabled: Bool) -> SplunkRumBuilder {
        self.enableDiskCache = enabled
        return self
    }

    @discardableResult
    @objc
    public func spanDiskCacheMaxSize(size: Int64) -> SplunkRumBuilder {
        self.spanDiskCacheMaxSize = size
        return self
    }

    @discardableResult
    @objc
    public func slowRenderingDetectionEnabled(_ enabled: Bool) -> SplunkRumBuilder {
        self.slowRenderingDetectionEnabled = enabled
        return self
    }

    @discardableResult
    @objc
    public func slowFrameDetectionThresholdMs(thresholdMs: Double) -> SplunkRumBuilder {
        self.slowFrameDetectionThresholdMs = thresholdMs
        return self
    }

    @discardableResult
    @objc
    public func frozenFrameDetectionThresholdMs(thresholdMs: Double) -> SplunkRumBuilder {
        self.frozenFrameDetectionThresholdMs = thresholdMs
        return self
    }

    @discardableResult
    @objc
    public func sessionSamplingRatio(samplingRatio: Double) -> SplunkRumBuilder {
        self.sessionSamplingRatio = samplingRatio
        return self
    }

    @discardableResult
    @objc
    public func setApplicationName(_ appName: String) -> SplunkRumBuilder {
        self.appName = appName
        return self
    }

    @discardableResult
    @objc
    public func setSpanSchedulingDelay(seconds: TimeInterval) -> SplunkRumBuilder {
        self.spanSchedulingDelay = seconds
        return self
    }

    @discardableResult
    @objc
    public func build() -> Bool {
        return SplunkRum.create(beaconUrl: self.beaconUrl,
                                rumAuth: self.rumAuth,
                                appName: self.appName,
                                options: .init(allowInsecureBeacon: self.allowInsecureBeacon,
                                               debug: self.debug,
                                               globalAttributes: self.globalAttributes,
                                               environment: self.environment,
                                               ignoreURLs: self.ignoreURLs,
                                               showVCInstrumentation: self.showVCInstrumentation,
                                               screenNameSpans: self.screenNameSpans,
                                               networkInstrumentation: self.networkInstrumentation,
                                               enableDiskCache: self.enableDiskCache,
                                               spanDiskCacheMaxSize: self.spanDiskCacheMaxSize,
                                               slowRenderingDetectionEnabled: self.slowRenderingDetectionEnabled,
                                               slowFrameDetectionThresholdMs: self.slowFrameDetectionThresholdMs,
                                               frozenFrameDetectionThresholdMs: self.frozenFrameDetectionThresholdMs,
                                               sessionSamplingRatio: self.sessionSamplingRatio,
                                               spanSchedulingDelay: self.spanSchedulingDelay))
    }
}
