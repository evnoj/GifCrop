// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GifCrop",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.0"),
    ],
    targets: [
        .target(name: "GifCropShared", path: "Sources/GifCropShared"),
        .executableTarget(
            name: "GifCrop",
            dependencies: ["GifCropShared"],
            path: "Sources/GifCrop"),
        // Named GifCropCLI so it doesn't collide with GifCrop on a case-insensitive filesystem;
        // the build script installs it into the app bundle as `gifcrop`.
        .executableTarget(
            name: "GifCropCLI",
            dependencies: [
                "GifCropShared",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/GifCropCLI"),
    ]
)
