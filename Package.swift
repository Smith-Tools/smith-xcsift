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
        .package(path: "../smith-core"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "SmithXCSift",
            dependencies: [
                .product(name: "SmithCore", package: "smith-core"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "SmithXCSiftTests",
            dependencies: ["SmithXCSift"]
        ),
    ]
)