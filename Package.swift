// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AiNexus",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AiNexus",
            targets: ["AiNexus"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "10.0.0"
        ),
    ],
    targets: [
        .target(
            name: "AiNexus",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            ],
            path: "Ai Nexus"
        ),
    ]
)
