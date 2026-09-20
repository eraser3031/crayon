// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Crayon",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Crayon", targets: ["Crayon"])],
    targets: [
        .target(name: "Crayon"),
        .testTarget(name: "CrayonTests", dependencies: ["Crayon"])
    ]
)
