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
import GoogleMaps

class AViewController: UIViewController {
    override func viewDidLoad() {
           super.viewDidLoad()
           // Do any additional setup after loading the view.
           // Create a GMSCameraPosition that tells the map to display the
           // coordinate -33.86,151.20 at zoom level 6.
           let camera = GMSCameraPosition.camera(withLatitude: -33.86, longitude: 151.20, zoom: 6.0)
           let mapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
           self.view.addSubview(mapView)

           // Creates a marker in the center of the map.
           let marker = GMSMarker()
           marker.position = CLLocationCoordinate2D(latitude: -33.86, longitude: 151.20)
           marker.title = "Sydney"
           marker.snippet = "Australia"
           marker.map = mapView
     }

    @IBAction public func aAction() {
        print("a action")
    }
}
