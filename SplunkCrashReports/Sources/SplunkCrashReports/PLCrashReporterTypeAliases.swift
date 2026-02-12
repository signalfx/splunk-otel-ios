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

// MARK: - PLCrashReporter type aliases for SPM compatibility

//
// When building as an xcframework, PLCrashReporter is compiled with
// PLCRASHREPORTER_PREFIX=Splunk so all public ObjC classes are prefixed
// (e.g. PLCrashReporter → SplunkPLCrashReporter) to avoid symbol
// collisions with customer-provided instances.
//
// When building via Swift Package Manager, PLCrashReporter is pulled
// from upstream without the prefix, so the original names are exported.
//
// These typealiases let the rest of the codebase use the prefixed names
// consistently, regardless of the build path.

#if SWIFT_PACKAGE
    import CrashReporter

    typealias SplunkPLCrashReporter = PLCrashReporter
    typealias SplunkPLCrashReporterConfig = PLCrashReporterConfig
    typealias SplunkPLCrashReport = PLCrashReport
    typealias SplunkPLCrashReportThreadInfo = PLCrashReportThreadInfo
    typealias SplunkPLCrashReportStackFrameInfo = PLCrashReportStackFrameInfo
    typealias SplunkPLCrashReportBinaryImageInfo = PLCrashReportBinaryImageInfo
#endif
