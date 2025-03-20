// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "SplunkOtel",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
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
