// swift-tools-version:5.8

import PackageDescription

let package = Package(
  name: "SwiftDependencyMagnet",
  platforms: [.macOS(.v12)],
  products: [
    .executable(name: "dependency_magnet", targets: ["DependencyMagnet"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.1"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
  ],
  targets: [
    .executableTarget(
      name: "DependencyMagnet",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Yams", package: "Yams"),
        "DependencyMagnetLib",
      ],
      path: "Sources/DependencyMagnet"
    ),
    .target(
      name: "DependencyMagnetLib",
      dependencies: [],
      path: "Sources/DependencyMagnetLib"
    ),
  ]
)
