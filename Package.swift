// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexSwitch",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "CodexSwitch", targets: ["CodexSwitch"]),
        .executable(name: "CodexSwitchDebugPreview", targets: ["CodexSwitchDebugPreview"]),
        .library(name: "CodexSwitchPreview", type: .dynamic, targets: ["CodexSwitchPreview"])
    ],
    targets: [
        .target(
            name: "CodexSwitchPreview"
        ),
        .executableTarget(
            name: "CodexSwitch",
            dependencies: ["CodexSwitchPreview"]
        ),
        .executableTarget(
            name: "CodexSwitchDebugPreview",
            dependencies: ["CodexSwitchPreview"]
        )
    ]
)
