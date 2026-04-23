// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MacAgent",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacAgent", targets: ["MacAgent"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/livekit/webrtc-xcframework.git",
            revision: "29ba04430bca89c866d3eda2d08b7ca653607a66"
        )
    ],
    targets: [
        .executableTarget(
            name: "MacAgent",
            dependencies: [
                .product(name: "LiveKitWebRTC", package: "webrtc-xcframework")
            ],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Network")
            ]
        ),
        .testTarget(
            name: "MacAgentTests",
            dependencies: ["MacAgent"]
        )
    ]
)
