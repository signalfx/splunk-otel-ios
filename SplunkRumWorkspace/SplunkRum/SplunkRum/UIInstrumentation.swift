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
    // FIXME will probably need to grow a config feature to silence chatty actions
    // FIXME really only a reasonable solution for storyboard apps/components and not swiftui ones
    @objc open func swizzled_sendAction(_ action: Selector,
                                        to target: Any?,
                                        from sender: Any?,
                                        for event: UIEvent?) -> Bool {
        let tracer = buildTracer()
        let span = tracer.spanBuilder(spanName: action.description).startSpan()
        var scope = tracer.setActive(span)
        defer {
            scope.close()
            span.end()
        }
        if target != nil {
            span.setAttribute(key: "target.type", value: String(describing: type(of: target!)))
        }
        if sender != nil {
            span.setAttribute(key: "sender.type", value: String(describing: type(of: sender!)))
        }
        if event != nil {
            span.setAttribute(key: "event.type", value: String(describing: type(of: event!)))
        }
        return swizzled_sendAction(action, to: target, from: sender, for: event)
    }
}

extension UIViewController {
    @objc open func swizzled_loadView() {
        print("SWIZZLED LOADVIEW "+String(describing: type(of: self)))
        self.swizzled_loadView()
    }
    @objc open func swizzled_viewDidLoad() {
        print("SWIZZLED VIEWDIDLOAD "+String(describing: type(of: self)))
        self.swizzled_viewDidLoad()
    }
    @objc open func swizzled_viewWillAppear(_ animated: Bool) {
        print("SWIZZLED VIEWWILLAPPEAR "+String(describing: type(of: self)))
        self.swizzled_viewWillAppear(animated)
    }
    @objc open func swizzled_viewDidAppear(_ animated: Bool) {
        print("SWIZZLED VIEWDIDAPPEAR "+String(describing: type(of: self)))
        self.swizzled_viewDidAppear(animated)
    }
    @objc open func swizzled_viewWillDisappear(_ animated: Bool) {
        print("SWIZZLED VIEWWILLDISAPPEAR "+String(describing: type(of: self)))
        self.swizzled_viewWillDisappear(animated)
    }
    @objc open func swizzled_viewDidDisappear(_ animated: Bool) {
        print("SWIZZLED VIEWDIDDISAPPEAR "+String(describing: type(of: self)))
        self.swizzled_viewDidDisappear(animated)
    }

}

func initalizeUIInstrumentation() {
    _ = NotificationCenter.default.addObserver(forName: nil, object: nil, queue: nil) { (_: Notification) in
        // print("NC "+using.debugDescription)
    }
    swizzle(clazz: UIApplication.self, orig: #selector(UIApplication.sendAction(_:to:from:for:)), swizzled: #selector(UIApplication.swizzled_sendAction(_:to:from:for:)))
    swizzle(clazz: UIViewController.self, orig: #selector(UIViewController.loadView), swizzled: #selector(UIViewController.swizzled_loadView))
    swizzle(clazz: UIViewController.self, orig: #selector(UIViewController.viewDidLoad), swizzled: #selector(UIViewController.swizzled_viewDidLoad))
    swizzle(clazz: UIViewController.self, orig: #selector(UIViewController.viewWillAppear(_:)), swizzled: #selector(UIViewController.swizzled_viewWillAppear(_:)))
    swizzle(clazz: UIViewController.self, orig: #selector(UIViewController.viewDidAppear(_:)), swizzled: #selector(UIViewController.swizzled_viewDidAppear(_:)))
    swizzle(clazz: UIViewController.self, orig: #selector(UIViewController.viewWillDisappear(_:)), swizzled: #selector(UIViewController.swizzled_viewWillDisappear(_:)))
    swizzle(clazz: UIViewController.self, orig: #selector(UIViewController.viewDidDisappear(_:)), swizzled: #selector(UIViewController.swizzled_viewDidDisappear(_:)))

}
