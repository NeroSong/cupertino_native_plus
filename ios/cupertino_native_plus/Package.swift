// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cupertino_native_plus",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(
            name: "cupertino-native-plus",
            targets: ["cupertino_native_plus"]
        ),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/SVGKit/SVGKit", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "cupertino_native_plus",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "SVGKit", package: "SVGKit"),
            ],
            path: "Sources/cupertino_native_plus",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
