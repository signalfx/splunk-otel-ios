// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SplunkOtel",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_13)
    ],
    products: [
        .library(name: "SplunkOtel", targets: ["SplunkOtel"])
    ],
    targets: [
        .target(
            name: "SplunkOtel",
            path: "SplunkRumWorkspace/SplunkRum",
            exclude: [
                "SplunkRumTests",
                "SplunkRumDiskExportTests",
                "SplunkRum/SplunkRum.h",
                "SplunkRum/Info.plist"
            ],
            sources: [
                "SplunkRum",
            ],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
