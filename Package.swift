// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "bzip2JavApi",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "bzip2JavApi",
            targets: ["bzip2JavApi"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "bzip2JavApi"),
        .testTarget(
            name: "bzip2JavApiTests",
            dependencies: ["bzip2JavApi"]
        ),
    ]
)
