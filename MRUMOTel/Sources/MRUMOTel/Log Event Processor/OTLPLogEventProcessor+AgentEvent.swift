//
//  MRUM SDK, © 2024 CISCO
//

import Foundation
import OpenTelemetryApi
import MRUMSharedProtocols

extension OTLPLogEventProcessor {

    /// Builds LogRecordBuilder from supplied AgentEvent and initial LogRecordBuilder.
    ///
    /// - Parameters:
    ///   - event: An event with which the LogRecordBuilder is built from.
    ///   - logRecordBuilder: Initial LogRecordBuilder, which is extented with data from the Event.
    func buildEvent(with event: any Event, logRecordBuilder: LogRecordBuilder) -> LogRecordBuilder {
        
        // Initialise attribute dictionary
        var otelAttributes: [String: AttributeValue] = [:]
        
        // Attributes - session ID
        if let sessionID = event.sessionID {
            otelAttributes["session.id"] = AttributeValue(sessionID)
        }
        
        // Attributes - event.domain
        otelAttributes["event.domain"] = AttributeValue(event.domain)
        
        // Attributes - event.name
        otelAttributes["event.name"] = AttributeValue(event.name)

        // Merge with provided attributes
        if let providedAttributes = event.attributes {
            for (attributeName, attributeValue) in providedAttributes {
                otelAttributes[attributeName] = AttributeValue(attributeValue)
            }
        }
    
        // Start building the builder
        let resultingBuilder = logRecordBuilder
        
        // Add attributes
        if !otelAttributes.isEmpty {
            _ = resultingBuilder.setAttributes(otelAttributes)
        }

        // Add body
        if let body = event.body {
            _ = resultingBuilder.setBody(AttributeValue(body))
        }

        // Add timestamp
        if let timestamp = event.timestamp {
            _ = resultingBuilder.setTimestamp(timestamp)
        }

        return resultingBuilder
    }
}
