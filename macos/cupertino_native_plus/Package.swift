// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cupertino_native_plus",
    platforms: [
        .macOS("11.0"),
    ],
    products: [
        .library(
            name: "cupertino-native-plus",
            targets: ["cupertino_native_plus"]
        ),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "cupertino_native_plus",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/cupertino_native_plus",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
