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

import XCTest

public class NanoIDValidator {

    // MARK: - Basic checks

    public static func checkFormat(_ nanoID: String) throws {
        let allowedCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
        let allowedCharactersSet = CharacterSet(charactersIn: allowedCharacters)

        // The default call should produce an ID with a length of 21 characters
        XCTAssertTrue(nanoID.count == 21)

        // Only allowed characters must be used for ID creation
        let hasForbiddenCharacters = nanoID.rangeOfCharacter(from: allowedCharactersSet.inverted) != nil
        XCTAssertFalse(hasForbiddenCharacters)
    }
}
