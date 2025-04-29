import Foundation
import SplunkWebView
import SplunkCommon
import WebKit

extension WebViewInstrumentation: Module {
    convenience public init() {}

    public typealias Configuration = Void // No configuration
    public typealias RemoteConfiguration = Void // No remote configuration

    // Module conformance
    public typealias EventMetadata = Void
    public typealias EventData = Void

    public func install(with configuration: (any ModuleConfiguration)?,
                       remoteConfiguration: (any SplunkCommon.RemoteModuleConfiguration)?) {}

    public func onPublish(data: @escaping (Void, Void) -> Void) {}

    public func deleteData(for metadata: Any) {}
}
