// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "YijiCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "YijiCore",
            targets: ["YijiCore"]
        )
    ],
    targets: [
        .target(
            name: "YijiCore"
        ),
        .testTarget(
            name: "YijiCoreTests",
            dependencies: ["YijiCore"]
        )
    ]
)
