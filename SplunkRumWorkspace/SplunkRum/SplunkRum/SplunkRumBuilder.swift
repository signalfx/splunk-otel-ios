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
import StdoutExporter

@objc public class SplunkRumBuilder: NSObject {

     var beaconUrl: String!
     var rumToken: String!
     var allowInsecureBeacon: Bool = false
     var debug: Bool = false
     var globalAttributes: [String: Any] = [:]
     var environment: String?
     var ignoreURLs: NSRegularExpression?
     var spanFilter: ((SpanData) -> SpanData?)?
     var showVCInstrumentation: Bool = true
     var screenNameSpans: Bool = true
     var networkInstrumentation: Bool = true
     var slowFrameDetectionThresholdMs: Double = 16.7
     var frozenFrameDetectionThresholdMs: Double = 700
     var enableDiskCache: Bool = false
     var spanDiskCacheMaxSize: Int64 = DEFAULT_DISK_CACHE_MAX_SIZE_BYTES
     var sessionSamplingRatio: Double = 1.0

    @objc @discardableResult public func setBeaconUrl(beaconUrl: String) -> SplunkRumBuilder {
        self.beaconUrl = beaconUrl
        return self
    }

    @objc @discardableResult public func setRumToken(rumtoken: String) -> SplunkRumBuilder {
        self.rumToken = rumtoken
        return self
    }

    @objc @discardableResult public func setAllowInsecureBeacon(allowInsecure: Bool) -> SplunkRumBuilder {
        self.allowInsecureBeacon = allowInsecure
        return self
    }

    @objc @discardableResult public func setDebug(debug: Bool) -> SplunkRumBuilder {
        self.debug = debug
        return self
    }

    @objc @discardableResult public func setGlobalAttributes(_ attributes: [String: Any]) -> SplunkRumBuilder {
        self.globalAttributes = attributes
        return self
    }

    @objc @discardableResult public func setDeploymentEnvironment(environment: String) -> SplunkRumBuilder {
        self.environment = environment
        return self

    }

    @objc @discardableResult public func setIgnoreURLs(ignoreURL: NSRegularExpression) -> SplunkRumBuilder {
        self.ignoreURLs = ignoreURL
        return self
    }

    public func setSpanFilter(spanData: @escaping ((SpanData) -> SpanData?)) -> SplunkRumBuilder {
        self.spanFilter = spanData
        return self
    }

    @objc @discardableResult public func setShowVCInstrumentation(showVCInstrumentation: Bool) -> SplunkRumBuilder {
        self.showVCInstrumentation = showVCInstrumentation
        return self
    }

    @objc @discardableResult public func setScreenNameSpans(screenNameSpans: Bool) -> SplunkRumBuilder {
        self.screenNameSpans = screenNameSpans
        return self
    }

    @objc @discardableResult public func setNetworkInstrumentation(networkInstrumentation: Bool) -> SplunkRumBuilder {
        self.networkInstrumentation = networkInstrumentation
        return self
    }

    @objc @discardableResult public func setSlowFrameRenders(duration: Double) -> SplunkRumBuilder {
        self.slowFrameDetectionThresholdMs = duration
        return self
    }

    @objc @discardableResult public func setFrozenFrameRenders(duration: Double) -> SplunkRumBuilder {
        self.frozenFrameDetectionThresholdMs = duration
        return self
    }

    @objc @discardableResult public func setEnableDiskCache(enableDiskCache: Bool) -> SplunkRumBuilder {
        self.enableDiskCache = enableDiskCache
        return self
    }

    @objc @discardableResult public func build() -> SplunkRumOptions {

            let rumOptional = SplunkRumOptions()
                rumOptional.beaconUrl = self.beaconUrl
                rumOptional.rumToken = self.rumToken
                rumOptional.allowInsecureBeacon = self.allowInsecureBeacon
                rumOptional.debug = self.debug
                rumOptional.environment = self.environment
                rumOptional.showVCInstrumentation = self.showVCInstrumentation
                rumOptional.screenNameSpans = self.screenNameSpans
                rumOptional.globalAttributes = self.globalAttributes
                rumOptional.spanDiskCacheMaxSize = self.spanDiskCacheMaxSize
                rumOptional.frozenFrameDetectionThresholdMs = self.frozenFrameDetectionThresholdMs
                rumOptional.slowFrameDetectionThresholdMs = self.slowFrameDetectionThresholdMs
                rumOptional.spanFilter = self.spanFilter
                rumOptional.ignoreURLs = self.ignoreURLs
                rumOptional.enableDiskCache = self.enableDiskCache

                if self.beaconUrl != nil || self.rumToken != nil {
                  SplunkRum.splunkRum_Initialize(beaconUrl: self.beaconUrl, rumAuth: self.rumToken, options: rumOptional)
                }

                return rumOptional
    }
}
