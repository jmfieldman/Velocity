// swift-tools-version:5.8

import PackageDescription

let package = Package(
  name: "SwiftDependencyMagnet",
  platforms: [.macOS(.v12)],
  products: [
    .executable(name: "dependency_magnet", targets: ["DependencyMagnet"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.3.1"),
    .package(url: "https://github.com/apple/swift-crypto.git", exact: "3.1.0"),
    .package(url: "https://github.com/jpsim/Yams.git", exact: "5.0.6"),
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
      dependencies: [
        .product(name: "Crypto", package: "swift-crypto"),
      ],
      path: "Sources/DependencyMagnetLib"
    ),
  ]
)
