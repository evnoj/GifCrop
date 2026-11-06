// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GifCrop",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(name: "GifCrop", path: "Sources/GifCrop")
    ]
)
