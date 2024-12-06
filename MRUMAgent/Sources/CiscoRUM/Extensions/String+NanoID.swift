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

extension String {

    static func uniqueIdentifier(ofLength length: Int = 21) -> String {
        let uniqueIdentifierCharactersSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
        let uniqueCharactersCount = uniqueIdentifierCharactersSet.count

        var identifier = ""

        while identifier.count != length {
            let randomCharacterPosition = Int.random(in: 0 ..< uniqueCharactersCount)
            let index = uniqueIdentifierCharactersSet.index(uniqueIdentifierCharactersSet.startIndex, offsetBy: randomCharacterPosition)
            let randomCharacter = uniqueIdentifierCharactersSet[index]

            identifier += String(randomCharacter)
        }

        return identifier
    }
}
