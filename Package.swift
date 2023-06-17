// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NSView+Intercept",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "NSView+Intercept",
            targets: ["NSView+Intercept"]),
    ],
    targets: [
        .target(
            name: "NSView+Intercept",
            dependencies: [])
    ]
)
