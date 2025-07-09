// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Networking",
            targets: ["Networking"]
        ),
    ],
    dependencies: [
        .package(path: "Storage"),
        .package(path: "Utility"),
        .package(url: "https://github.com/Alamofire/Alamofire", exact: "5.10.2"),
        .package(url: "https://github.com/auth0/JWTDecode.swift", exact: "3.1.0")
    ],
    targets: [
        .target(
            name: "Networking",
            dependencies: [
                "Storage",
                "Utility",
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "JWTDecode", package: "JWTDecode.swift")
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
