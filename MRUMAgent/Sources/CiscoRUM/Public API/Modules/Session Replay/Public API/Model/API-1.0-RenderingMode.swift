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

import Foundation

/// A video rendering mode for captured data.
public enum RenderingMode: Equatable, Codable {

    /// Render the video as the screen images and also
    /// as a wireframe representation of screen data.
    case native

    /// Render the video only as a wireframe representation of screen data.
    case wireframe

    /// Render the whole screen as a gray image.
    /// Actual content is not part of the final video.
    case noRendering
}


public extension RenderingMode {

    /// Default video rendering mode.
    static let `default` = RenderingMode.native
}
