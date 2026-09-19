// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AppDabKit",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11)],
    products: [.library(name: "AppDabServices", targets: ["AppDabServices"])],
    dependencies: [
        .package(url: "https://github.com/MortenGregersen/AppStoreConnectKit", from: "4.0.0"),
        .package(url: "https://github.com/MortenGregersen/Bagbutik", from: "24.0.3")
    ],
    targets: [
        .target(
            name: "AppDabServices",
            dependencies: [
                "AppDabBagbutikExtensions",
                .product(name: "BagbutikCore", package: "Bagbutik"),
                .product(name: "BagbutikAppStore", package: "Bagbutik"),
                .product(name: "ConnectAccounts", package: "AppStoreConnectKit")
            ]
        ),
        .testTarget(
            name: "AppDabServicesTests",
            dependencies: [
                "AppDabServices",
                .product(name: "BagbutikCore", package: "Bagbutik"),
                .product(name: "BagbutikAppStore", package: "Bagbutik"),
                .product(name: "ConnectAccounts", package: "AppStoreConnectKit")
            ]
        ),
        .target(
            name: "AppDabBagbutikExtensions",
            dependencies: [
                .product(name: "BagbutikAppStore", package: "Bagbutik")
            ]
        )
    ]
)
