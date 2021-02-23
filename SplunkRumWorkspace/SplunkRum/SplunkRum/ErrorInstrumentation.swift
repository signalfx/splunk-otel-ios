//
//  ErrorInstrumentation.swift
//  SplunkRum
//
//  Created by jbley on 2/23/21.
//

import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

// FIXME fix span names throughout
// FIXME add component= to all spans
// FIXME differentiate between reaching here from the uncaught handler vs manual SplunkRum.error call
func reportExceptionErrorSpan(e: NSException) {
    // FIXME decide on instr name/version
    // FIXME versioning in config somewhere
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios", instrumentationVersion: "0.0.1")
    let now = Date()
    let span = tracer.spanBuilder(spanName: "UncaughtException").setStartTime(time: now).startSpan()
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "error.name", value: e.name.rawValue)
    if e.reason != nil {
        span.setAttribute(key: "error.message", value: e.reason!)
    }
    let stack = e.callStackSymbols.joined(separator: "\n")
    if !stack.isEmpty {
        span.setAttribute(key: "error.stack", value: stack)
    }
    span.end(time: now)
    // App likely crashing now; last-ditch effort to force-flush
    OpenTelemetrySDK.instance.tracerProvider.forceFlush()
}

var oldExceptionHandler: ((NSException) -> Void)?
func ourExceptionHandler(e: NSException) {
    print("Got an exception")
    reportExceptionErrorSpan(e: e)
    if oldExceptionHandler != nil {
        oldExceptionHandler!(e)
    }

}

func initializeUncaughtExceptionReporting() {
    oldExceptionHandler = NSGetUncaughtExceptionHandler()
    NSSetUncaughtExceptionHandler(ourExceptionHandler(e:))
}

func reportErrorErrorSpan(e: Error) {
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios", instrumentationVersion: "0.0.1")
    let now = Date()
    let span = tracer.spanBuilder(spanName: "UncaughtException").setStartTime(time: now).startSpan()
    print("TYPE OF ERROR "+String(describing: type(of: e)))
    span.setAttribute(key: "error", value: true)    
    let className = objectTypeName(o: e as NSObject)
    if className != nil {
        span.setAttribute(key: "error.name", value: className!)
    } else {
        // FIXME try using this more often...
        span.setAttribute(key: "error.name", value: String(describing: type(of: e)))
    }
    span.setAttribute(key: "error.message", value: e.localizedDescription)
    span.end(time: now)
}

func reportStringErrorSpan(e: String) {
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ios", instrumentationVersion: "0.0.1")
    let now = Date()
    let span = tracer.spanBuilder(spanName: "UncaughtException").setStartTime(time: now).startSpan()
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "error.name", value: "String")
    span.setAttribute(key: "error.message", value: e)
    span.end(time: now)
}

