// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GlobalTimeKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "GlobalTimeKit", targets: ["GlobalTimeKit"])
    ],
    targets: [
        .target(
            name: "GlobalTimeKit",
            dependencies: [],
            path: "Sources",
            resources: [.process("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "GlobalTimeKitTests",
            dependencies: ["GlobalTimeKit"],
            path: "GlobalTimeKitTests"
        )
    ]
)
