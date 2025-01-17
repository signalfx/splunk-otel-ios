// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MRUMSlowFrameDetector",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "MRUMSlowFrameDetector",
            targets: [
                "MRUMSlowFrameDetector"
            ]
        )
    ],
    dependencies: [
        .package(name: "MRUMSharedProtocols",
                 path: "../MRUMSharedProtocols"),
        .package(name: "MRUMOTel",
                 path: "../MRUMOTel")
    ],
    targets: [
        .target(
            name: "MRUMSlowFrameDetector",
            dependencies: [
                .product(name: "MRUMSharedProtocols",
                         package: "MRUMSharedProtocols"),
                .product(name: "MRUMOTel",
                         package: "MRUMOTel")
            ]
        ),
        .testTarget(
            name: "MRUMSlowFrameDetectorTests",
            dependencies: ["MRUMSlowFrameDetector"]
        )
    ]
)
