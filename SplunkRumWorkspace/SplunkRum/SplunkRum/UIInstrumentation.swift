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
import UIKit

extension UIApplication {
    // FIXME really only a reasonable solution for storyboard apps/components and not swiftui ones
    @objc open func splunk_swizzled_sendAction(_ action: Selector,
                                               to target: Any?,
                                               from sender: Any?,
                                               for event: UIEvent?) -> Bool {
        updateUIFields()
        let tracer = buildTracer()
        let span = tracer.spanBuilder(spanName: Constants.SpanNames.ACTION).startSpan()
        span.setAttribute(key: Constants.AttributeNames.COMPONENT, value: "ui")
        span.setAttribute(key: Constants.AttributeNames.ACTION_NAME, value: action.description)
        OpenTelemetry.instance.contextProvider.setActiveSpan(span)
        defer {
            OpenTelemetry.instance.contextProvider.removeContextForSpan(span)
            span.end()
        }
        if target != nil {
            span.setAttribute(key: Constants.AttributeNames.TARGET_TYPE, value: String(describing: type(of: target!)))
        }
        if sender != nil {
            span.setAttribute(key: Constants.AttributeNames.SENDER_TYPE, value: String(describing: type(of: sender!)))
        }
        if event != nil {
            span.setAttribute(key: Constants.AttributeNames.EVENT_TYPE, value: String(describing: type(of: event!)))
        }
        return splunk_swizzled_sendAction(action, to: target, from: sender, for: event)
    }
}

extension UIViewController {
    @objc open func splunk_swizzled_viewDidLoad() {
        updateUIFields()
        self.splunk_swizzled_viewDidLoad()
    }
    @objc open func splunk_swizzled_viewDidAppear(_ animated: Bool) {
        updateUIFields()
        self.splunk_swizzled_viewDidAppear(animated)
    }
    @objc open func splunk_swizzled_viewDidDisappear(_ animated: Bool) {
        updateUIFields()
        self.splunk_swizzled_viewDidDisappear(animated)
    }

}

class SpanHolder: NSObject {
    let span: Span
    init(_ span: Span) {
        self.span = span
    }
}

class NotificationPairInstrumener {
    let obj2Span = NSMapTable<NSObject, SpanHolder>(keyOptions: NSPointerFunctions.Options.weakMemory, valueOptions: NSPointerFunctions.Options.strongMemory)
    let begin: String
    let end: String
    let spanName: String
    init(begin: String, end: String, spanName: String) {
        self.begin = begin
        self.end = end
        self.spanName = spanName
    }
    func start() {
        let beginName = Notification.Name(rawValue: begin)
        let endName = Notification.Name(rawValue: end)

        _ = NotificationCenter.default.addObserver(forName: beginName, object: nil, queue: nil) { (notif) in
            let notifObj = notif.object as? NSObject
            if notifObj != nil {
                let span = buildTracer().spanBuilder(spanName: self.spanName).startSpan()
                // captured at beginning since it will possibly/likely change
                span.setAttribute(key: Constants.AttributeNames.LAST_SCREEN_NAME, value: getScreenName())
                span.setAttribute(key: Constants.AttributeNames.COMPONENT, value: "ui")
                // FIXME better naming
                span.setAttribute(key: Constants.AttributeNames.OBJECT_TYPE, value: String(describing: type(of: notif.object!)))
                self.obj2Span.setObject(SpanHolder(span), forKey: notifObj)
            }

        }
        _ = NotificationCenter.default.addObserver(forName: endName, object: nil, queue: nil) { (notif) in
            updateUIFields()
            let notifObj = notif.object as? NSObject
            if notifObj != nil {
                let spanHolder = self.obj2Span.object(forKey: notifObj)
                if spanHolder != nil {
                    // screenName may have changed now that the view has appeared; update new screen name
                    spanHolder?.span.setAttribute(key: Constants.AttributeNames.SCREEN_NAME, value: getScreenName())
                    spanHolder?.span.end()
                }
            }
        }

    }
}

let PresentationTransitionInstrumenter = NotificationPairInstrumener(
    begin: "UIPresentationControllerPresentationTransitionWillBeginNotification",
    end: "UIPresentationControllerPresentationTransitionDidEndNotification",
    spanName: Constants.SpanNames.PRESENTATION_TRANSITION)

func initializePresentationTransitionInstrumentation() {
    PresentationTransitionInstrumenter.start()
    _ = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "_UIWindowSystemGestureStateChangedNotification"), object: nil, queue: nil) { (_) in
        updateUIFields()
    }
}

let ShowVCInstrumenter = NotificationPairInstrumener(
    begin: "UINavigationControllerWillShowViewControllerNotification",
    end: "UINavigationControllerDidShowViewControllerNotification",
    spanName: Constants.SpanNames.SHOW_VC)

func initializeShowVCInstrumentation() {
    ShowVCInstrumenter.start()
}

// FIXME possibly also use for segues/scenes?

func addUIFields(span: ReadableSpan) {
    updateUIFields()
    // Note that this may be called from threads other than main (e.g., background thread
    // creating span); hence trying to update cached values whenever we can and simply using
    // them here
    span.setAttribute(key: Constants.AttributeNames.SCREEN_NAME, value: getScreenName())
}

private func pickVC(_ vc: UIViewController?) -> UIViewController? {
    if vc == nil {
        return nil
    }
    if let nav = vc as? UINavigationController {
        if nav.visibleViewController != nil {
            return pickVC(nav.visibleViewController)
        }
        if nav.topViewController != nil {
            return pickVC(nav.topViewController)
        }
    }
    if let tabVC = vc as? UITabBarController {
        if tabVC.selectedViewController != nil {
            return pickVC(tabVC.selectedViewController)
        }
    }
    if let page = vc as? UIPageViewController {
        if page.viewControllers != nil && !page.viewControllers!.isEmpty {
            return pickVC(page.viewControllers![0])
        }
    }
    if vc!.presentedViewController != nil {
        return pickVC(vc!.presentedViewController)
    }
    return vc
}

private func pickWindow() -> UIWindow? {
    let app = UIApplication.shared
    // just using app.keyWindow is depcrecated now
    let key = app.windows.last { $0.isKeyWindow }
    if key != nil {
        return key
    }
    let wins = app.windows
    if !wins.isEmpty {
        // windows are arranged in z-order, with topmost (e.g. popover) being the last in array
        return wins[wins.count-1]
    }
    return nil
}

private func updateUIFields() {
    if !Thread.current.isMainThread {
        return
    }
    if isScreenNameManuallySet() {
        return
    }
    let win = pickWindow()
    if win != nil {
        // windows are arranged in z-order, with topmost (e.g. popover) being the last in array
        let vc = pickVC(win!.rootViewController)
        if vc != nil {
            // FIXME SwiftUI UIHostingController vc when cast has a "rootView" var which does
            // not appear to be accessible generically
            internal_setScreenName(String(describing: type(of: vc!)), false)
        }
    }
    // FIXME others?
}

func initalizeUIInstrumentation() {
    initializePresentationTransitionInstrumentation()
    if SplunkRum.configuredOptions?.showVCInstrumentation ?? true {
        initializeShowVCInstrumentation()
    }

    swizzle(clazz: UIApplication.self, orig: #selector(UIApplication.sendAction(_:to:from:for:)), swizzled: #selector(UIApplication.splunk_swizzled_sendAction(_:to:from:for:)))
    swizzle(clazz: UIViewController.self, orig: #selector(UIViewController.viewDidLoad), swizzled: #selector(UIViewController.splunk_swizzled_viewDidLoad))
    swizzle(clazz: UIViewController.self, orig: #selector(UIViewController.viewDidAppear(_:)), swizzled: #selector(UIViewController.splunk_swizzled_viewDidAppear(_:)))
    swizzle(clazz: UIViewController.self, orig: #selector(UIViewController.viewDidDisappear(_:)), swizzled: #selector(UIViewController.splunk_swizzled_viewDidDisappear(_:)))

}
