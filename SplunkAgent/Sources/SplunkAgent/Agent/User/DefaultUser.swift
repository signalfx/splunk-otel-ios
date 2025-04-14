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

/// The object implements the logic around the agent user.
class DefaultUser: AgentUser {

    // MARK: - Private

    var userModel: UserModel


    // MARK: - Public

    private(set) lazy var userIdentifier: String = userModel.prepareIdentifier()

    var trackingMode: UserTrackingMode {
        get {
            userModel.trackingMode
        }
        set {
            userModel.trackingMode = newValue
        }
    }


    // MARK: - Initialization

    required init(userModel: UserModel = UserModel()) {
        self.userModel = userModel
    }
}
