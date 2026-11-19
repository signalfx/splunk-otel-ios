//
/*
Copyright 2026 Splunk Inc.

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

/// Span attribute keys for the runtime attributes the agent adds to every signal.
enum RuntimeAttributeKeys {

    /// Anonymous identifier of the user.
    static let userAnonymousId = "user.anonymous_id"

    /// Identifier of the session the signal belongs to.
    static let sessionId = "session.id"

    /// Identifier of the application installation.
    static let appInstallationId = "app.installation.id"

    /// Name of the screen shown when the signal was created.
    static let screenName = "screen.name"
}
