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



import Foundation

public class SplunkRumBuilder {

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
    private var slowRenderingDetectionEnabled: Bool = true
    private var slowFrameDetectionThresholdMs: Double = 16.7
    private var frozenFrameDetectionThresholdMs: Double = 700
    private var sessionSamplingRatio: Double = 1.0
    private var appName: String?
    private var showVCInstrumentation: Bool = true
    
    private var endpointConfiguration: EndpointConfiguration

    @available(*, deprecated, message: "No longer supported.")
    public init(beaconUrl: String, rumAuth: String) {
        self.beaconUrl = beaconUrl
        self.rumAuth = rumAuth
        let endpointConfiguration = EndpointConfiguration(trace: URL(string: beaconUrl))
        self.agentConfiguration = AgentConfiguration(endpoint: <#T##EndpointConfiguration#>, appName: <#T##String#>, deploymentEnvironment: <#T##String#>)
    }

    @available(*, deprecated, message: "No longer supported.")
    public init(realm: String, rumAuth: String) {
        self.beaconUrl = "https://rum-ingest.\(realm).signalfx.com/v1/rum"
        self.rumAuth = rumAuth
        let endpointConfiguration = EndpointConfiguration(realm: realm, rumAccessToken: rumAuth)
    }

    @available(*, deprecated, message: "No longer supported.")
    @discardableResult
    public func debug(enabled: Bool) -> SplunkRumBuilder {
        self.debug = enabled
        return self
    }

    @available(*, deprecated, message: "No longer supported.")
    @discardableResult
    public func globalAttributes(globalAttributes: [String: Any]) -> SplunkRumBuilder {
        self.globalAttributes = globalAttributes
        return self
    }

    @available(*, deprecated, message: "No longer supported.")
    @discardableResult
    public func deploymentEnvironment(environment: String) -> SplunkRumBuilder {
        self.environment = environment
        return self
    }

    @available(*, deprecated, message: "No longer supported.")
    @discardableResult
    public func ignoreURLs(ignoreURLs: NSRegularExpression) -> SplunkRumBuilder {
        self.ignoreURLs = ignoreURLs
        return self
    }

    @available(*, deprecated, message: "No longer supported.")
    @discardableResult
    public func showVCInstrumentation(_ show: Bool) -> SplunkRumBuilder {
        self.showVCInstrumentation = show
        return self
    }

    @discardableResult
    public func screenNameSpans(enabled: Bool) -> SplunkRumBuilder {
        self.screenNameSpans = enabled
        return self
    }

    @discardableResult
    public func networkInstrumentation(enabled: Bool) -> SplunkRumBuilder {
        self.networkInstrumentation = enabled
        return self
    }

    @discardableResult
    public func enableDiskCache(enabled: Bool) -> SplunkRumBuilder {
        return self
    }

    @discardableResult
    public func sessionSamplingRatio(samplingRatio: Double) -> SplunkRumBuilder {
        self.sessionSamplingRatio = samplingRatio
        return self
    }

    @discardableResult
    public func setApplicationName(_ appName: String) -> SplunkRumBuilder {
        self.appName = appName
        return self
    }


    @discardableResult
    public func build() -> Bool {
        // TODO: SplunkRum.install
        return true
    }
}
