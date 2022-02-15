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

import UIKit
import WebKit
import SplunkRum
import CoreLocation

class ViewController: UIViewController, WKUIDelegate,CLLocationManagerDelegate {
    
    var locationManager:CLLocationManager!
    @IBOutlet var lblLat:UILabel!
    @IBOutlet var lblLongi:UILabel!
    @IBOutlet var lblAdd:UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
            locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestAlwaysAuthorization()

            if CLLocationManager.locationServicesEnabled(){
                locationManager.startUpdatingLocation()
                SplunkRum.locationName(true)
            }
    }

    @IBAction
    func clickMe() {
        print("I was clicked!")
        SplunkRum.setScreenName("CustomScreenName")

        let webview = WKWebView(frame: .zero)
        webview.uiDelegate = self
        let url = URL(string: "http://127.0.0.1:8989/page.html")
        let req = URLRequest(url: url!)
        view = webview
        SplunkRum.integrateWithBrowserRum(webview)
        
        webview.load(req)
    }
    
    //MARK: - location delegate methods
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let userLocation :CLLocation = locations[0] as CLLocation
    self.lblLat.text = "\(userLocation.coordinate.latitude)"
    self.lblLongi.text = "\(userLocation.coordinate.longitude)"

    let geocoder = CLGeocoder()
    geocoder.reverseGeocodeLocation(userLocation) { (placemarks, error) in
        if (error != nil){
            print("error in reverseGeocode")
        }
        let placemark = placemarks! as [CLPlacemark]
        if placemark.count>0{
            let placemark = placemarks![0]
//            print(placemark.locality!)
//            print(placemark.administrativeArea!)
//            print(placemark.country!)

            self.lblAdd.text = "\(placemark.locality!), \(placemark.administrativeArea!), \(placemark.country!)"
        }
    }

}
func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Error \(error)")
}

}
