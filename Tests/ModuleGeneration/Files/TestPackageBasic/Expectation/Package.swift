// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "TestPackage",
    platforms: [
        iOS
    ],
    products: [
        .library(name: "PackageOneImpl", targets: ["PackageOneImpl"]),
        .library(name: "PackageOne", targets: ["PackageOne"]),
        .library(name: "PackageThreeImpl", targets: ["PackageThreeImpl"]),
        .library(name: "PackageThree", targets: ["PackageThree"]),
        .library(name: "PackageTwoImpl", targets: ["PackageTwoImpl"]),
        .library(name: "PackageTwo", targets: ["PackageTwo"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "PackageOneImpl",
            dependencies: [
                "PackageOne",
            ],
            path: "../Modules/PackageOne/PackageOneImpl",
            exclude: [
                "LICENSE",
                "README.md",
                "imports.yml",
                "inject.yml",
            ]
        ),
        .target(
            name: "PackageOne",
            dependencies: [
                
            ],
            path: "../Modules/PackageOne/PackageOne",
            exclude: [
                "LICENSE",
                "README.md",
                "imports.yml",
                "inject.yml",
            ]
        ),
        .target(
            name: "PackageThreeImpl",
            dependencies: [
                "PackageOne",
                "PackageThree",
            ],
            path: "../Modules/RecursiveDirectory/PackageThree/PackageThreeImpl",
            exclude: [
                "LICENSE",
                "README.md",
                "imports.yml",
                "inject.yml",
            ]
        ),
        .target(
            name: "PackageThree",
            dependencies: [
                "PackageOne",
                "PackageTwo",
            ],
            path: "../Modules/RecursiveDirectory/PackageThree/PackageThree",
            exclude: [
                "LICENSE",
                "README.md",
                "imports.yml",
                "inject.yml",
            ]
        ),
        .target(
            name: "PackageTwoImpl",
            dependencies: [
                "PackageOne",
                "PackageTwo",
            ],
            path: "../Modules/PackageTwo/PackageTwoImpl",
            exclude: [
                "LICENSE",
                "README.md",
                "imports.yml",
                "inject.yml",
            ]
        ),
        .target(
            name: "PackageTwo",
            dependencies: [
                "PackageOne",
            ],
            path: "../Modules/PackageTwo/PackageTwo",
            exclude: [
                "LICENSE",
                "README.md",
                "imports.yml",
                "inject.yml",
            ]
        ),
    ]
)
