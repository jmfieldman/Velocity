// swift-tools-version:5.8

import PackageDescription

let package = Package(
  name: "SwiftDependencyMagnetTest",
  platforms: [.macOS(.v12)],
  products: [
    .executable(name: "DependencyMagnetTest", targets: ["DependencyMagnetTest"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.4.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", exact: "3.5.2"),
    .package(url: "https://github.com/jpsim/Yams.git", exact: "5.1.2"),
  ],
  targets: [
    .executableTarget(
      name: "DependencyMagnetTest",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Yams", package: "Yams"),
        "DependencyMagnetTestLib",
      ],
      path: "Sources/DependencyMagnetTest"
    ),
    .target(
      name: "DependencyMagnetTestLib",
      dependencies: [
        .product(name: "Crypto", package: "swift-crypto"),
      ],
      path: "Sources/DependencyMagnetTestLib"
    ),
  ]
)
