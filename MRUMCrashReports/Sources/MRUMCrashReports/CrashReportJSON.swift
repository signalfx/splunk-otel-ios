//
/*
Copyright 2024 Splunk Inc.

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

// JSON Support for Crash Reports.

public class CrashReportJSON {
    
    public static func convertDictionaryToJSONData(_ dictionary: [String: Any]) -> Data? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted) else {
            
            return nil
        }
        return jsonData
    }
    
    public static func convertDictionaryToJSONString(_ dictionary: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted) else {
            
            return nil
        }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            
            return nil
        }
        return jsonString
    }
}
