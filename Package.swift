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
        ),
        .testTarget(
            name: "MarkdownViewerTests",
            dependencies: ["MarkdownViewer"],
            path: "Tests",
            swiftSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ], .when(platforms: [.macOS]))
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ], .when(platforms: [.macOS]))
            ]
        ),
    ]
)
