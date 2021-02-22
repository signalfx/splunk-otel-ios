//
//  InstrumentationUtils.swift
//  SplunkRum
//
//  Created by jbley on 2/22/21.
//

import Foundation
import UIKit
import OpenTelemetryApi
import OpenTelemetrySdk

private func addUIFields(span: ReadableSpan) {
    let wins = UIApplication.shared.windows
    if !wins.isEmpty {
        // windows are arranged in z-order, with topmost (e.g. popover) being the last in array
        let vc = wins[wins.count-1].rootViewController
        if vc != nil {
            let clazz = object_getClass(vc)
            if clazz != nil {
                let className = NSStringFromClass(clazz!)
                // FIXME demangle swift names
                span.setAttribute(key: "screen.name", value: className)
            }
            // FIXME SwiftUI UIHostingController vc when cast has a "rootView" var which does
            // not appear to be accessible generically
        }
    }
    // FIXME others?
}

func addPreSpanFields(span: ReadableSpan) {
    addUIFields(span: span)
}
