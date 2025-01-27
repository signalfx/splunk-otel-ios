//
//  MRUM SDK, © 2024 CISCO
//

import Foundation
import MRUMSharedProtocols
import OpenTelemetryApi

extension AttributeValue {
    public init(_ eventAttributeValue: EventAttributeValue) {
        switch eventAttributeValue {
        case let .string(eventAttributeValue):
            self = .string(eventAttributeValue)

        case let .int(eventAttributeValue):
            self = .int(eventAttributeValue)

        case let .double(eventAttributeValue):
            self = .double(eventAttributeValue)

        case let .data(eventAttributeValue):
            // ‼️ Placeholder solution
            self = .string(eventAttributeValue.base64EncodedString())
        }
    }
}
