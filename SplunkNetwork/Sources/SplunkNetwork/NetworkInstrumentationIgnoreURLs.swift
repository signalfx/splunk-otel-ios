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

/// A class that holds an array of regular expressions for URL patterns to ignore
/// and provides functionality to work with them.
public class IgnoreURLs: Codable {
    /// The stored regular expressions.
    private var urlPatterns: [NSRegularExpression]

    /// Initialize with an empty set of URL patterns.
    public init() {
        urlPatterns = []
    }

    /// Initialize with a set of URL pattern strings.
    ///
    /// - Parameter patterns: Set of regular expression pattern strings for URLs.
    ///
    /// - Throws: If any of the patterns are invalid regular expressions.
    public init(patterns: Set<String>) throws {
        urlPatterns = try patterns.map { pattern in
            try NSRegularExpression(pattern: pattern, options: [])
        }
    }

    /// Initialize with an optional `NSRegularExpression` pattern.
    ///
    /// - Parameter pattern: Optional `NSRegularExpression` for URL pattern matching.
    public init(containing pattern: NSRegularExpression?) {
        if let pattern {
            urlPatterns = [pattern]
        }
        else {
            urlPatterns = []
        }
    }

    /// Initialize from a decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    ///
    /// - Throws: If the decoder contains invalid data or if any patterns are invalid regular expressions.
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let patterns = try container.decode(Set<String>.self, forKey: .patterns)
        urlPatterns = try patterns.map { pattern in
            try NSRegularExpression(pattern: pattern, options: [])
        }
    }

    /// Coding keys for the IgnoreURLs class.
    private enum CodingKeys: String, CodingKey {
        case patterns
    }

    /// Encode the instance to an encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: If the encoder fails to encode the data.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Set(getAllPatterns()), forKey: .patterns)
    }

    /// Clear all URL patterns from the instance.
    ///
    /// - Returns: The number of patterns that were cleared.
    @discardableResult
    public func clearPatterns() -> Int {
        let count = urlPatterns.count
        urlPatterns.removeAll()
        return count
    }

    /// Add additional URL patterns to the existing set.
    ///
    /// - Parameter patterns: Set of regular expression pattern strings for URLs to add.
    ///
    /// - Throws: If any of the new patterns are invalid regular expressions.
    ///
    /// - Returns: The number of patterns added.
    @discardableResult
    public func addPatterns(_ patterns: Set<String>) throws -> Int {
        let newPatterns = try patterns.map { pattern in
            try NSRegularExpression(pattern: pattern, options: [])
        }

        let existingPatternStrings = Set(urlPatterns.map(\.pattern))
        let uniqueNewPatterns = newPatterns.filter { !existingPatternStrings.contains($0.pattern) }
        urlPatterns.append(contentsOf: uniqueNewPatterns)
        return uniqueNewPatterns.count
    }

    /// Add a single NSRegularExpression pattern to the existing set.
    ///
    /// - Parameter pattern: NSRegularExpression pattern to add.
    ///
    /// - Returns: true if the pattern was added, false if it already existed.
    @discardableResult
    public func addPattern(_ pattern: NSRegularExpression) -> Bool {
        let existingPatternStrings = Set(urlPatterns.map(\.pattern))

        if !existingPatternStrings.contains(pattern.pattern) {
            urlPatterns.append(pattern)
            return true
        }

        return false
    }

    /// Get the number of URL patterns.
    public func count() -> Int {
        urlPatterns.count
    }

    /// Get all URL patterns as strings.
    ///
    /// - Returns: Array of pattern strings.
    public func getAllPatterns() -> [String] {
        urlPatterns.map(\.pattern)
    }

    /// Check if a URL string matches any of the ignore patterns.
    ///
    /// - Parameter urlString: The URL string to check.
    ///
    /// - Returns: True if the URL matches any pattern.
    public func matches(_ urlString: String) -> Bool {
        urlPatterns.contains { regex in
            let range = NSRange(urlString.startIndex..., in: urlString)
            return regex.firstMatch(in: urlString, options: [], range: range) != nil
        }
    }

    /// Check if a URL matches any of the ignore patterns.
    ///
    /// - Parameter url: The URL to check.
    ///
    /// - Returns: True if the URL matches any pattern.
    public func matches(url: URL) -> Bool {
        matches(url.absoluteString)
    }
}
