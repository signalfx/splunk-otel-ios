//
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
import SplunkSharedProtocols

/// OTLPLogEventProcessor sends OpenTelemetry Logs enriched with Resources via an instantiated background exporter.
public class OTLPLogToSpanEventProcessor: LogEventProcessor {

    // MARK: - Private properties

    // OTel tracer processor
    private let tracerProcessor: TraceProcessor


    // MARK: - Initialization

    required public init(with tracesEndpoint: URL, resources: AgentResources, debugEnabled: Bool) {
        self.tracerProcessor = OTLPTraceProcessor(with: tracesEndpoint, resources: resources, debugEnabled: debugEnabled)
    }


    // MARK: - Events

    public func sendEvent(_ event: any Event, completion: @escaping (Bool) -> Void) {
        sendEvent(event: event, immediateProcessing: false, completion: completion)
    }

    public func sendEvent(event: any Event, immediateProcessing: Bool , completion: @escaping (Bool) -> Void) {

        tracerProcessor.sendEvent(event: event, completion: completion)
    }
}
