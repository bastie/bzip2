// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "bzip2JavApi",
  platforms: [.macOS(.v15)],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "bzip2JavApi",
      targets: ["bzip2JavApi"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/bastie/JavApi4Swift.git",
      from: "0.25.0"
    )
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "bzip2JavApi",
      dependencies: [.product(name: "JavApi", package: "JavApi4Swift")]
    ),
    .testTarget(
      name: "bzip2JavApiTests",
      dependencies: ["bzip2JavApi"]
    ),
  ]
)
