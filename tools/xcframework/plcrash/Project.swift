// tools/xcframework/plcrash/Project.swift
//
// Tuist manifest that wraps PLCrashReporter source files into a dynamic
// framework target suitable for xcframework creation.
//
// PLCrashReporter is a C/ObjC/C++ crash reporting library. The source
// is expected at `vendor/plcrashreporter/` (cloned by the build script
// before `tuist generate`).
//
// Key build settings:
//   - MACH_O_TYPE = mh_dylib       →  dynamic framework (upstream only ships static)
//   - SKIP_INSTALL = NO            →  archives include the framework in Products/
//   - DEFINES_MODULE = YES         →  generates the module map for Swift interop
//   - MODULEMAP_FILE              →  points to the existing module.modulemap
//   - CLANG_ENABLE_MODULES = YES   →  enables module imports in ObjC
//
// Platform matrix: iOS, tvOS, Mac Catalyst (no visionOS — PLCrashReporter
// doesn't support it).

import ProjectDescription

// ---------------------------------------------------------------------------
// MARK: - Source Paths
// ---------------------------------------------------------------------------

/// Root of PLCrashReporter source, relative to this Project.swift.
let plcrashRoot = "vendor/plcrashreporter"

// ---------------------------------------------------------------------------
// MARK: - Shared Build Settings
// ---------------------------------------------------------------------------

/// Common settings for the PLCrashReporter framework target.
let sharedSettings: SettingsDictionary = [
    // Produce a dynamic framework instead of static library.
    "MACH_O_TYPE": "mh_dylib",

    // Include the framework in xcodebuild archive output.
    "SKIP_INSTALL": "NO",

    // Generate a module for Swift consumers.
    "DEFINES_MODULE": "YES",

    // PLCrashReporter C preprocessor defines (matching upstream Package.swift).
    //
    // PLCRASHREPORTER_PREFIX renames all public ObjC/C symbols to avoid
    // collisions when customers also embed their own PLCrashReporter.
    // The same prefix is patched into PLCrashNamespace.h by the build
    // script so that the shipped headers expose the prefixed names.
    "GCC_PREPROCESSOR_DEFINITIONS": [
        "PLCR_PRIVATE=1",
        "PLCF_RELEASE_BUILD=1",
        "PLCRASHREPORTER_PREFIX=Splunk",
        "SWIFT_PACKAGE=1"
    ],

    // Header search paths for the bundled protobuf-c dependency.
    "HEADER_SEARCH_PATHS": [
        "$(SRCROOT)/\(plcrashRoot)/Dependencies/protobuf-c",
        "$(SRCROOT)/\(plcrashRoot)/Source"
    ],

    // Minimum deployment targets.
    "IPHONEOS_DEPLOYMENT_TARGET": "13.0",
    "TVOS_DEPLOYMENT_TARGET": "13.0",
    "MACOSX_DEPLOYMENT_TARGET": "10.15",

    // Support Mac Catalyst builds.
    "SUPPORTS_MACCATALYST": "YES",

    // Link Foundation framework.
    "OTHER_LDFLAGS": ["-framework", "Foundation"],

    // Allow ObjC++ compilation.
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": "c++17",

    // Prefix header: ensures PLCrashNamespace.h (and its #define renames)
    // is included before any other header in every compilation unit.
    // Without this, private headers that don't include PLCrashNamespace.h
    // declare classes with the original names, while the @implementation
    // (after PLCrashNamespace.h is eventually included) uses prefixed
    // names — causing a class name mismatch.
    "GCC_PREFIX_HEADER": "$(SRCROOT)/\(plcrashRoot)/Source/PLCrashNamespace.h",
    "GCC_PRECOMPILE_PREFIX_HEADER": "YES",

    // Install the public headers into the framework.
    "PUBLIC_HEADERS_FOLDER_PATH": "$(CONTENTS_FOLDER_PATH)/Headers"
]


// ---------------------------------------------------------------------------
// MARK: - Source file lists
// ---------------------------------------------------------------------------
// PLCrashReporter source structure: C, ObjC, C++, ObjC++, and assembly files.
// We exclude C++ headers (.hpp) as they are implementation-only and would
// cause issues if included as sources. The proto file is also excluded.

/// Header files that should be public (exposed in the framework).
///
/// Note: PLCrashReport*.h glob matches PLCrashReporter.h, PLCrashReporterConfig.h,
/// and all PLCrashReportXxx.h headers — no need to list them individually.
let publicHeaders: FileList = [
    "\(plcrashRoot)/Source/CrashReporter.h",
    "\(plcrashRoot)/Source/PLCrashReport*.h",
    "\(plcrashRoot)/Source/PLCrashMacros.h",
    "\(plcrashRoot)/Source/PLCrashFeatureConfig.h",
    "\(plcrashRoot)/Source/PLCrashNamespace.h",
    "\(plcrashRoot)/Source/PLCrashCompatConstants.h"
]


// ---------------------------------------------------------------------------
// MARK: - Project Definition
// ---------------------------------------------------------------------------

let project = Project(
    name: "PLCrashReporterXCFrameworks",
    settings: .settings(
        base: sharedSettings,
        configurations: [
            .debug(name: "Debug", settings: [:]),
            .release(name: "Release", settings: [:])
        ]
    ),
    targets: [
        .target(
            name: "CrashReporter",
            destinations: [
                .iPhone, .iPad, // iOS
                .appleTv, // tvOS
                .macCatalyst // Mac Catalyst
                // No visionOS — PLCrashReporter doesn't support it
            ],
            product: .framework,
            bundleId: "org.plcrashreporter.CrashReporter",
            sources: [
                .glob("\(plcrashRoot)/Source/**/*.c"),
                .glob("\(plcrashRoot)/Source/**/*.m"),
                .glob("\(plcrashRoot)/Source/**/*.mm"),
                .glob("\(plcrashRoot)/Source/**/*.cpp"),
                .glob("\(plcrashRoot)/Source/**/*.S"),
                .glob("\(plcrashRoot)/Dependencies/protobuf-c/**/*.c")
            ],
            headers: .headers(
                public: publicHeaders,
                private: [
                    "\(plcrashRoot)/Source/**/*.h",
                    "\(plcrashRoot)/Dependencies/protobuf-c/**/*.h"
                ],
                project: []
            ),
            settings: .settings(
                base: [
                    "PRODUCT_MODULE_NAME": "CrashReporter",
                    "INFOPLIST_KEY_CFBundleDisplayName": "CrashReporter",
                    "PRODUCT_NAME": "CrashReporter"
                ]
            )
        )
    ]
)
