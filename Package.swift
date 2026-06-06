// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "康纳音乐",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "康纳音乐", targets: ["康纳音乐"])
    ],
    targets: [
        .executableTarget(
            name: "康纳音乐",
            path: "Sources/MusicPlayer",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
            ]
        )
    ]
)
