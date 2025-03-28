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


// MARK: - Beating Heart

struct PulsatingEffect: ViewModifier {
    
    /// We really only need this to be true, but if we start it out as true, there's no change of state to kick off the animation.
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1 : 0.5)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true),
                    value: UUID()
            ).onAppear() {
                isAnimating = true
            }
    }
}

extension View {
    func pulsating() -> some View {
        self.modifier(PulsatingEffect())
    }
}

struct BeatingHeart: View {
    var body: some View {
        Image(systemName: "heart.fill")
            .resizable()
            .frame(width: 100, height: 100)
            .foregroundColor(.red)
            .pulsating()
    }
}
