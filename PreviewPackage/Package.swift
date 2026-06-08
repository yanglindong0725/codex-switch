// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexSwitchPreviewPackage",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "CodexSwitchPreview", type: .dynamic, targets: ["CodexSwitchPreview"])
    ],
    targets: [
        .target(
            name: "CodexSwitchPreview"
        )
    ]
)
