// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MusicPlayer",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MusicPlayer",
            path: "Sources/MusicPlayer",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
            ]
        )
    ]
)
