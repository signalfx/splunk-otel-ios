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
import CoreLocation
import UIKit
import SwiftUI

func initalizeLocationInstrumentation() {
    CLLocationManager.swizzleCLLocationManager()
}
extension CLLocationManager {
@objc static func swizzleCLLocationManager() {
      guard self == CLLocationManager.self else {
            return
          }

      let originalCLManagerDelegateSelector = #selector(setter: self.delegate)
      let swizzledCLManagerDelegateSelector = #selector(self.splunk_set(delegate:))

      let originalCLLocationManagerMethod = class_getInstanceMethod(self, originalCLManagerDelegateSelector)
      let swizzledCLLocationManagerMethod = class_getInstanceMethod(self, swizzledCLManagerDelegateSelector)

      method_exchangeImplementations(originalCLLocationManagerMethod!,
                                     swizzledCLLocationManagerMethod!)
}
@objc open func splunk_set(delegate: CLLocationManagerDelegate?) {
    splunk_set(delegate: delegate)
    guard let delegate =  delegate else { return }
    let originalMethodSelector = #selector(delegate.locationManager(_:didUpdateLocations:))
    let swizzleMethodSelector = #selector(self.splunk_swizzled_didUpdateLocations(with:locations:))

     let swizzleMethod = class_getInstanceMethod(CLLocationManager.self, swizzleMethodSelector)
     let didAddMethod = class_addMethod(type(of: delegate),
                                        swizzleMethodSelector,
                                        method_getImplementation(swizzleMethod!),
                                        method_getTypeEncoding(swizzleMethod!))

     if didAddMethod {
       let didSelectOriginalMethod = class_getInstanceMethod(type(of: delegate), swizzleMethodSelector)
       let didSelectSwizzledMethod = class_getInstanceMethod(type(of: delegate), originalMethodSelector)
       if didSelectOriginalMethod != nil && didSelectSwizzledMethod != nil {
         method_exchangeImplementations(didSelectOriginalMethod!, didSelectSwizzledMethod!)
       }
     }
  }

@objc open func splunk_swizzled_didUpdateLocations(with manager: CLLocationManager, locations: [CLLocation]) {
    locations.forEach { (location) in
        SplunkRum.setGlobalAttributes(["location.lon": location.coordinate.longitude])
        SplunkRum.setGlobalAttributes(["location.lat": location.coordinate.latitude])
    }
    splunk_swizzled_didUpdateLocations(with: manager, locations: locations)
 }
}
