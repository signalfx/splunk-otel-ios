import SplunkAgent
import SwiftUI

struct TrackingDemoView: View {
    // Reference to the tracking module instance
    let trackingModule: CustomTrackingModule = /* Initialize your tracking module here */

    // Define a custom Swift error for demonstration
    enum DemoError: Error {
        case sampleError
    }

    var body: some View {
        VStack {
            // Keep the header as is
            DemoHeaderView()
            
            Spacer()
            
            // Add labeled buttons for each track function
            VStack(spacing: 16) {
                Button("Track Custom Event") {
                    let attributes = MutableAttributes()
                    attributes.set("key", value: "value")
                    trackingModule.trackCustomEvent("CustomEventName", attributes)
                }
                .buttonStyle(.borderedProminent)

                Button("Track Error (String)") {
                    trackingModule.trackError("A simple error message")
                }
                .buttonStyle(.borderedProminent)
                
                Button("Track Error (Swift Error)") {
                    let swiftError: Error = DemoError.sampleError
                    trackingModule.trackError(swiftError)
                }
                .buttonStyle(.borderedProminent)

                Button("Track Error (NSError)") {
                    let nsError = NSError(domain: "MyApp", code: 456, userInfo: nil)
                    trackingModule.trackError(nsError)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Track Exception (NSException)") {
                    let exception = NSException(name: .genericException, reason: "Something went wrong", userInfo: nil)
                    trackingModule.trackException(exception)
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Tracking Demo") // Set navigation title
    }
}