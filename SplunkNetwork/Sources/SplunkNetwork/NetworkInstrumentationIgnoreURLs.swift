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

public class IgnoreURLs: Codable {
    private var urlPatterns: [NSRegularExpression]
    
    public init() {
        self.urlPatterns = []
    }
    
    public init(patterns: Set<String>) throws {
        self.urlPatterns = try patterns.map { pattern in
            try NSRegularExpression(pattern: pattern, options: [])
        }
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let patterns = try container.decode(Set<String>.self, forKey: .patterns)
        self.urlPatterns = try patterns.map { pattern in
            try NSRegularExpression(pattern: pattern, options: [])
        }
    }

    private enum CodingKeys: String, CodingKey {
        case patterns
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Set(getAllPatterns()), forKey: .patterns)
    }

    @discardableResult
    public func clearPatterns() -> Int {
        let count = urlPatterns.count
        urlPatterns.removeAll()
        return count
    }
    
    @discardableResult
    public func addPatterns(_ patterns: Set<String>) throws -> Int {
        let newPatterns = try patterns.map { pattern in
            try NSRegularExpression(pattern: pattern, options: [])
        }
        
        let existingPatternStrings = Set(urlPatterns.map { $0.pattern })
        let uniqueNewPatterns = newPatterns.filter { !existingPatternStrings.contains($0.pattern) }
        urlPatterns.append(contentsOf: uniqueNewPatterns)
        return uniqueNewPatterns.count
    }
    
    public func count() -> Int {
        return urlPatterns.count
    }
    
    public func getAllPatterns() -> [String] {
        return urlPatterns.map { $0.pattern }
    }
    
    public func matches(_ urlString: String) -> Bool {
        return urlPatterns.contains { regex in
            let range = NSRange(urlString.startIndex..., in: urlString)
            return regex.firstMatch(in: urlString, options: [], range: range) != nil
        }
    }
    
    public func matches(url: URL) -> Bool {
        return matches(url.absoluteString)
    }
} 
