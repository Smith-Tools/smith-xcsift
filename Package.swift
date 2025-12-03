// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "smith-xcsift",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "smith-xcsift",
            targets: ["SmithXCSift"]
        ),
    ],
    dependencies: [
        .package(path: "../smith-build-analysis"),
        .package(path: "../smith-foundation/SmithProgress"),
        .package(path: "../smith-foundation/SmithOutputFormatter"),
        .package(path: "../smith-foundation/SmithErrorHandling"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "SmithXCSift",
            dependencies: [
                .product(name: "SmithBuildAnalysis", package: "smith-build-analysis"),
                .product(name: "SmithProgress", package: "SmithProgress"),
                .product(name: "SmithOutputFormatter", package: "SmithOutputFormatter"),
                .product(name: "SmithErrorHandling", package: "SmithErrorHandling"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SmithXCSiftTests",
            dependencies: ["SmithXCSift"]
        ),
    ]
)