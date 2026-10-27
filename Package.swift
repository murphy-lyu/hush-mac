// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "HushCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "HushCore", targets: ["HushCore"])],
    targets: [
        .target(name: "HushCore", path: "HushCore"),
        .testTarget(name: "HushCoreTests", dependencies: ["HushCore"], path: "Tests")
    ]
)
