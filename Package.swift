// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacMiddleClick",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacMiddleClick", targets: ["MacMiddleClick"])],
    targets: [
        .target(name: "CMultitouch"),
        .target(name: "MacMiddleClickCore"),
        .executableTarget(name: "MacMiddleClick", dependencies: ["CMultitouch", "MacMiddleClickCore"]),
        .testTarget(name: "MacMiddleClickCoreTests", dependencies: ["MacMiddleClickCore"])
    ]
)
