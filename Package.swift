// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "OversizeMacro",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "OversizeMacro",
            targets: ["OversizeMacro"]
        ),
        .executable(
            name: "OversizeMacroClient",
            targets: ["OversizeMacroClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", .upToNextMajor(from: "601.0.0")),
    ],
    targets: [
        .macro(
            name: "OversizeMacroMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(name: "OversizeMacro", dependencies: ["OversizeMacroMacros"]),
        .executableTarget(name: "OversizeMacroClient", dependencies: ["OversizeMacro"]),
        .testTarget(
            name: "OversizeMacroTests",
            dependencies: [
                "OversizeMacro",
                "OversizeMacroMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
