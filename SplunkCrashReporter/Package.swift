// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplunkCrashReporter",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(name: "SplunkCrashReporter", targets: ["SplunkCrashReporter"])
    ],
    targets: [
        .target(
            name: "SplunkCrashReporter",
            path: "",
            exclude: [
                "Source/dwarf_opstream.hpp",
                "Source/dwarf_stack.hpp",
                "Source/PLCrashAsyncDwarfCFAState.hpp",
                "Source/PLCrashAsyncDwarfCIE.hpp",
                "Source/PLCrashAsyncDwarfEncoding.hpp",
                "Source/PLCrashAsyncDwarfExpression.hpp",
                "Source/PLCrashAsyncDwarfFDE.hpp",
                "Source/PLCrashAsyncDwarfPrimitives.hpp",
                "Source/PLCrashAsyncLinkedList.hpp",
                "Source/PLCrashReport.proto"
            ],
            sources: [
                "Source",
                "Dependencies/protobuf-c"
            ],
            cSettings: [
                .define("PLCR_PRIVATE"),
                .define("PLCF_RELEASE_BUILD"),
                .define("PLCRASHREPORTER_PREFIX", to: "SPLK"),
                .define("SWIFT_PACKAGE"), // Should be defined by default, Xcode 11.1 workaround.
                .headerSearchPath("Dependencies/protobuf-c"),
                .unsafeFlags(["-w"]) // Suppresses "Implicit conversion" warnings in protobuf.c
            ],
            linkerSettings: [
                .linkedFramework("Foundation")
            ]
        )
    ]
)
