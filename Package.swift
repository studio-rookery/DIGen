// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DIGen",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "DIGen",
            targets: ["DIGen"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.32.0")
    ],
    targets: [
        .target(
            name: "DIGen",
            dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten")
            ]),
        .testTarget(
            name: "DIGenTests",
            dependencies: ["DIGen"]),
    ]
)
