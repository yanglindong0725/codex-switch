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
        .library(name: "CodexSwitchCore", targets: ["CodexSwitchCore"]),
        .library(name: "CodexSwitchPreview", type: .dynamic, targets: ["CodexSwitchPreview"])
    ],
    targets: [
        .target(
            name: "CodexSwitchCore"
        ),
        .target(
            name: "CodexSwitchPreview",
            dependencies: ["CodexSwitchCore"]
        ),
        .executableTarget(
            name: "CodexSwitch",
            dependencies: ["CodexSwitchCore", "CodexSwitchPreview"]
        ),
        .executableTarget(
            name: "CodexSwitchDebugPreview",
            dependencies: ["CodexSwitchPreview"]
        ),
        .testTarget(
            name: "CodexSwitchCoreTests",
            dependencies: ["CodexSwitchCore"]
        )
    ]
)
