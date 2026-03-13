// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PasteDock",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "PasteDock",
            targets: ["PasteDockApp"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "PasteDockApp"
        ),
    ]
)
