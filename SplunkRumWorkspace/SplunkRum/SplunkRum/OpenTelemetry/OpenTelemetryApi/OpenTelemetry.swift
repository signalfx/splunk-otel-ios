/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// This class provides a static global accessor for telemetry objects Tracer, Meter
///  and BaggageManager.
///  The telemetry objects are lazy-loaded singletons resolved via ServiceLoader mechanism.
public struct OpenTelemetry {
    
    public static var version = "v1.7.0"
    
    public static var instance = OpenTelemetry()

    /// Registered tracerProvider or default via DefaultTracerProvider.instance.
    public private(set) var tracerProvider: TracerProvider

    /// registered manager or default via  DefaultBaggageManager.instance.
    public private(set) var baggageManager: BaggageManager

    /// registered manager or default via  DefaultBaggageManager.instance.
    public private(set) var propagators: ContextPropagators = DefaultContextPropagators(textPropagators: [W3CTraceContextPropagator()], baggagePropagator: W3CBaggagePropagator())

    /// registered manager or default via  DefaultBaggageManager.instance.
    public private(set) var contextProvider: OpenTelemetryContextProvider

    private init() {
        tracerProvider = DefaultTracerProvider.instance
        baggageManager = DefaultBaggageManager.instance
        contextProvider = OpenTelemetryContextProvider(contextManager: ActivityContextManager.instance)
    }

    public static func registerTracerProvider(tracerProvider: TracerProvider) {
        instance.tracerProvider = tracerProvider
    }

    public static func registerBaggageManager(baggageManager: BaggageManager) {
        instance.baggageManager = baggageManager
    }

    public static func registerPropagators(textPropagators: [TextMapPropagator], baggagePropagator: TextMapBaggagePropagator) {
        instance.propagators = DefaultContextPropagators(textPropagators: textPropagators, baggagePropagator: baggagePropagator)
    }

    public static func registerContextManager(contextManager: ContextManager) {
        instance.contextProvider.contextManager = contextManager
    }
}
