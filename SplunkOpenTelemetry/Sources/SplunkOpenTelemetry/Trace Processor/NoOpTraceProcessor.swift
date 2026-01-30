//
/*
Copyright 2025 Splunk Inc.

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
import SplunkCommon

/// NoOpTraceProcessor is a no-operation implementation that doesn't send traces.
///
/// This processor is used when no endpoint is configured, preventing traces from being sent
/// until a valid endpoint is provided.
public class NoOpTraceProcessor: TraceProcessor {

    public init() {}
}
