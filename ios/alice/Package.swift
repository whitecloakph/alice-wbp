// swift-tools-version: 5.9
// iOS part of the Alice fork (whitecloakph/alice-wbp): forwards the iOS shake
// gesture to Dart. See FORK.md.

import PackageDescription

let package = Package(
    name: "alice",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "alice", targets: ["alice"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "alice",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
