//
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

import CrashReporter
import Foundation

// Support for Code Images

extension CrashReports {

    /// The image list returned as a JSON encoded string.
    ///
    /// - Parameter:
    ///   - images: An array of items which, if they are eligible images,
    ///     will be added to the output.
    /// - Returns: A list of image data dictionaries if any, serialized as
    ///     a JSON string.
    func imageList(images: [Any]) -> String {
        var outputImages: [Any] = []
        for image in images {
            guard let image = image as? PLCrashReportBinaryImageInfo else {
                continue
            }
            // Only add the image to the list if it was noted in the stack traces
            if allUsedImageNames.contains(image.imageName) {
                var imageDictionary: [CrashReportKeys: Any] = [:]

                imageDictionary[.baseAddress] = image.imageBaseAddress
                imageDictionary[.imageSize] = image.imageSize
                imageDictionary[.imagePath] = image.imageName
                imageDictionary[.imageUUID] = image.imageUUID

                outputImages.append(imageDictionary)
            }
        }
        return convertToJSONString(outputImages) ?? "unknown"
    }
}
