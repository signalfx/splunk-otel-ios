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
    @objc open func swizzled_sendAction(_ action: Selector,
                                        to target: Any?,
                                        from sender: Any?,
                                        for event: UIEvent?) -> Bool {
        print("--- SEND ACTION")
        print(action)
        print(target)
        print(sender)
        print(event)
        print("---")
        return swizzled_sendAction(action, to: target, from: sender, for: event)
    }
}

func initalizeUIInstrumentation() {
    NotificationCenter.default.addObserver(forName: nil, object: nil, queue: nil) { (using: Notification) in
        print("NC "+using.debugDescription)
    }
    swizzle(clazz: UIApplication.self, orig: #selector(UIApplication.sendAction(_:to:from:for:)), swizzled: #selector(UIApplication.swizzled_sendAction(_:to:from:for:)))

}
