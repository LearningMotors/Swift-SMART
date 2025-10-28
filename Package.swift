// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SMART",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SMART",
            targets: ["SMART"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SMART",
            dependencies: [],
            path: ".",
            sources: [
                "Sources/Client",
                "Sources/iOS", 
                "Sources/SMART",
                "OAuth2",
                "FHIR"
            ],
            swiftSettings: [
                .define("NO_MODEL_IMPORT"),
                .define("NO_MODULE_IMPORT"),
                .define("NO_KEYCHAIN_IMPORT")
            ]
        ),
        .testTarget(
            name: "SMARTTests",
            dependencies: ["SMART"],
            path: "Tests"
        ),
    ]
)