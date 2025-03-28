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

import SwiftUI


// MARK: - Sleep Button

enum DemoStallType: CaseIterable {
    case short, medium, long

    var duration: TimeInterval {
        switch self {
        case .short: return 1.0
        case .medium: return 5.0
        case .long: return 15.0
        }
    }

    var description: String {
        return String(describing: self)
    }
}

extension DemoStallType: DemoSpoilerProvider {
    var spoiler: String {
        switch self {
        case .short: return "(will not be reported)"
        case .medium: return "(will exceed threshold)"
        case .long: return "(will exceed maxANRDuration)"
        }
    }
}


/// DemoSleepButton both creates the button and also does the action
/// stall: .short, .medium, or .long
/// isTriggered: controls the "Condition: normal/ANR" text in the host view
struct DemoSleepButton: View {

    let stall: DemoStallType
    @Binding var triggered: Bool

    init(_ stall: DemoStallType, _ isTriggered: Binding<Bool>) {
        self.stall = stall
        self._triggered = isTriggered
    }
    
    var body: some View {
        
        var units: String {
            stall.duration == 1 ? "second" : "seconds"
        }
        
        return Button(action: {
            triggered = true
            /// Freeze the main thread for duration seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Thread.sleep(forTimeInterval: stall.duration)
                triggered = false
            }
        }) {
            VStack {
                Text("Trigger \(stall.description) ANR")
                    .font(.title)
                    .fontWeight(.bold)
                Text(stall.spoiler)
                Text("\(Int(stall.duration)) \(units)")
            }
        }
        .padding()
        .disabled(triggered)
    }
}
