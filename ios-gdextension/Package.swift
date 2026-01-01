// swift-tools-version: 5.9
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .unsafeFlags([
        "-Xfrontend", "-internalize-at-link",
        "-Xfrontend", "-lto=llvm-full",
        "-Xfrontend", "-conditional-runtime-records"
    ])
]

let linkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-dead_strip"])
]

let package = Package(
    name: "GodotIap",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "GodotIap", type: .dynamic, targets: ["GodotIap"]),
    ],
    dependencies: [
        .package(name: "SwiftGodot", path: "../SwiftGodot"),
        .package(url: "https://github.com/hyodotdev/openiap.git", from: "1.3.9")
    ],
    targets: [
        .target(
            name: "GodotIap",
            dependencies: [
                .product(name: "SwiftGodotRuntime", package: "SwiftGodot"),
                .product(name: "OpenIAP", package: "openiap")
            ],
            swiftSettings: swiftSettings,
            linkerSettings: linkerSettings
        ),
    ]
)
