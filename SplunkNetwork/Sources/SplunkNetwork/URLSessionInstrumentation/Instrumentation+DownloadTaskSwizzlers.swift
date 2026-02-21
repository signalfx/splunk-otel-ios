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
import OpenTelemetryApi

// MARK: - Download Task Swizzling

func swizzleDownloadTaskWithRequest() {
    let selector = #selector(URLSession.downloadTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDownloadTask)
    swizzleDownloadTaskCreationMethod(selector: selector) { session, argument, originalIMP in
        guard let request = argument as? URLRequest else {
            return originalIMP(session, selector, argument)
        }

        return createInstrumentedDownloadTask(session: session, request: request, selector: selector, originalIMP: originalIMP)
    }
}

func swizzleDownloadTaskWithURL() {
    let selector = #selector(URLSession.downloadTask(with:) as (URLSession) -> (URL) -> URLSessionDownloadTask)

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    // Get the original request-based IMP to bypass the swizzled version
    let requestSelector = #selector(URLSession.downloadTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDownloadTask)
    guard let originalRequestIMP = OriginalIMPs.downloadTaskWithRequest else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Original downloadTask(with: URLRequest) IMP not captured"
        }
        return
    }

    let block: @convention(block) (URLSession, URL) -> URLSessionDownloadTask = { session, url in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URL) -> URLSessionDownloadTask).self
        )

        let request = URLRequest(url: url)
        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, url)
        }

        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, url)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)

        // Call the ORIGINAL (un-swizzled) request-based method directly.
        // This bypasses the request-based swizzle, preventing double instrumentation
        // when trace header injection is disabled.
        let castedRequestIMP = unsafeBitCast(
            originalRequestIMP,
            to: (@convention(c) (URLSession, Selector, URLRequest) -> URLSessionDownloadTask).self
        )
        let task = castedRequestIMP(session, requestSelector, instrumentedRequest)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}
