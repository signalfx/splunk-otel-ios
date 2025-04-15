// ValidationUtils.swift

import Foundation
import SplunkLogger

// Constants for maximum allowed lengths
let maxKeyLength = 1024
let maxValueLength = 2048

/// Validates the lengths of keys and values in a dictionary of attributes.
/// Logs a warning message if any attribute exceeds the maximum length.
/// - Parameters:
///   - attributes: The dictionary of attributes to validate.
///   - logger: The logger to use for warning messages.
/// - Returns: A boolean indicating whether all attributes are valid.
func validateAttributeLengths(attributes: [String: EventAttributeValue], logger: InternalLogger) -> Bool {
    for (key, value) in attributes {
        if key.count > maxKeyLength {
            logger.log(level: .warning) {
                "Invalid key length for key '\(key)'. Not publishing this event."
            }
            return false
        }
        if let stringValue = value as? String, stringValue.count > maxValueLength {
            logger.log(level: .warning) {
                "Invalid value length for key '\(key)'. Not publishing this event."
            }
            return false
        }
    }
    return true
}