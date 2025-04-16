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
import UIKit

class CustomTracking: UIViewController {

    @IBOutlet var trackEventButton: UIButton!
    @IBOutlet var trackErrorButton: UIButton!
    @IBOutlet var resultView: UITextView!


    // MARK: - Track Event

    @IBAction func trackEventClicked(_ sender: UIButton) {

        print("Track Event Clicked")

        let staticAttributes: [String: EventAttributeValue] = [
            "name": .string("universe"),
            "age": .int(42)
        ]
        var event = SplunkTrackableEvent(typeName: "UserEvent", attributes: staticAttributes)
        event.set("location", value: "New York")
        event.set("temperature", value: 72)
        track(eventName: "SomeEvent", trackableEvent: event)

        let attributes = event.toEventAttributes()
        let formatted = prettyPrintAttributes(attributes)
        print(attributes)
        resultView.text = formatted
    }


    // MARK: - Track Error

    @IBAction func trackErrorClicked(_ sender: UIButton) {
        print("Track Error Clicked")
    }

    func formatAttributes(_ attributes: [String: EventAttributeValue]) -> String {
        var formatted = ""

        for (key, value) in attributes {
            let valueDescription: String
            switch value {
            case .string(let str):
                valueDescription = "\"\(str)\""
            case .int(let int):
                valueDescription = "\(int)"
            case .double(let double):
                valueDescription = "\(double)"
            case .data(let data):
                valueDescription = data.description
            }
            formatted += "\(key): \(valueDescription)\n"
        }

        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }


}




