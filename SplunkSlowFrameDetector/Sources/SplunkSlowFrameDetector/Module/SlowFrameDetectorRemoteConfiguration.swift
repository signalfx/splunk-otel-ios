public struct SlowFrameDetectorRemoteConfiguration: RemoteModuleConfiguration {

    // MARK: - Internal decoding

    struct SlowFrameDetector: Decodable {
        let enabled: Bool
    }

    struct MRUMRoot: Decodable {
        let slowFrameDetector: SlowFrameDetector
    }

    struct Configuration: Decodable {
        let mrum: MRUMRoot
    }

    struct Root: Decodable {
        let configuration: Configuration
    }


    // MARK: - Protocol conformance


    // MARK: - Internal variables

    public var enabled: Bool

    public init?(from data: Data) {
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return nil
        }
        enabled = root.configuration.mrum.slowFrameDetector.enabled
    }
}
