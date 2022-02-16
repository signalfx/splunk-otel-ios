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

class Corelocation: NSObject, CLLocationManagerDelegate {
    
    var locationManager : CLLocationManager = CLLocationManager()
    var latitude:String = String()
    var longitude:String = String()
    var locality:String = String()
    var administrativeArea:String = String()
    var country:String = String()
    
    
    override init() {
         super.init()
        rumMobileLocation()
    }
    
    func rumMobileLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled(){
            locationManager.startUpdatingLocation()
            
        }
    }
    
    //MARK: - location delegate methods
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let userLocation :CLLocation = locations[0] as CLLocation
    manager.delegate = nil;
      self.latitude  = "\(userLocation.coordinate.latitude)"
      self.longitude = "\(userLocation.coordinate.longitude)"
      let geocoder = CLGeocoder()
      geocoder.reverseGeocodeLocation(userLocation) { [self] (placemarks, error) in
        if (error != nil){
            print("error in reverseGeocode")
        }
        let placemark = placemarks! as [CLPlacemark]
        if placemark.count>0{
            let placemark = placemarks![0]
            self.locality  = "\(placemark.locality!)"
            self.administrativeArea  = "\(placemark.administrativeArea!)"
            self.country  = "\(placemark.country!)"

        }
        
    }

}
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Error \(error)")
  }
        
}
