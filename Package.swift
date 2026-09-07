// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Javis",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Javis", targets: ["Javis"]),
    ],
    targets: [
        .executableTarget(
            name: "Javis",
            path: "Sources"
        ),
    ]
)
