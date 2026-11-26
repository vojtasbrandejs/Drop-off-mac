// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Drop-off",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "DropOff", targets: ["DropOff"]),
    ],
    targets: [
        .executableTarget(
            name: "DropOff",
            path: "Sources/DropOff"
        ),
        .testTarget(
            name: "DropOffTests",
            dependencies: ["DropOff"],
            path: "Tests/DropOffTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
