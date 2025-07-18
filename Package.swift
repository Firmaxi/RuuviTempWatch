// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviTempWatch",
    defaultLocalization: "fi",
    platforms: [
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "RuuviTempWatch",
            targets: ["RuuviTempWatch"]),
    ],
    targets: [
        .target(
            name: "RuuviTempWatch",
            path: "RuuviTempWatch Watch App",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "RuuviTempWatchTests",
            dependencies: ["RuuviTempWatch"],
            path: "Tests"
        ),
    ]
)