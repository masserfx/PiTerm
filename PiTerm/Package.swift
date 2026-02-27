// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PiTerm",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(name: "swift-nio-ssh", path: "../swift-nio-ssh-fork"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        .target(
            name: "PiTerm",
            dependencies: [
                "SwiftTerm",
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            path: "PiTerm",
            exclude: ["Resources/Assets.xcassets", "Resources/PiTerm.entitlements"]
        ),
    ]
)
