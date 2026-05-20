// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MarkdownViewer",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "MarkdownViewer",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
