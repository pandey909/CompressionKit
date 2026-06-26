// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CompressionKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CompressionKit",
            targets: ["CompressionKit"]),
    ],
    targets: [
        .target(
            name: "CompressionKit",
            dependencies: []),
        .testTarget(
            name: "CompressionKitTests",
            dependencies: ["CompressionKit"]),
    ]
)
