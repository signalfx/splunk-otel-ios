struct LogDataEmitter {

    public func setupLogEmitter() {
        onPublish { metadata, eventData in

            let start = Time.now()

            var attributes = eventData.getAttributes()
            attributes["component"] = "customtracking"
            attributes["screen.name"] = "unknown"
            attributes["session.id"] = sharedState?.sessionId ?? "unknown"

            internalLogger.log(level: .info) {
                "Sending custom data: \(attributes?.debugDescription ?? "none")"
            }
        }
    }
}
