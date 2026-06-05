// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexSwitch",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "CodexSwitch", targets: ["CodexSwitch"])
    ],
    targets: [
        .executableTarget(
            name: "CodexSwitch",
            path: "Sources/CodexSwitch"
        )
    ]
)
