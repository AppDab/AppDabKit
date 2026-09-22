// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AppDabKit",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11)],
    products: [
        .library(name: "AppDabAutomation", targets: ["AppDabAutomation"]),
        .library(name: "AppDabServices", targets: ["AppDabServices"]),
        .library(name: "AppDabBagbutikExtensions", targets: ["AppDabBagbutikExtensions"]),
        .library(name: "AppDabKitTestSupport", targets: ["AppDabKitTestSupport"])
    ],
    dependencies: [
        .package(url: "https://github.com/MortenGregersen/AppStoreConnectKit", from: "4.1.0"),
        .package(url: "https://github.com/MortenGregersen/Bagbutik", from: "24.0.3")
    ],
    targets: [
        // Targets
        .target(name: "AppDabAutomation", dependencies: [
            "AppDabServices",
            .product(name: "BagbutikCore", package: "Bagbutik"),
            .product(name: "ConnectAccounts", package: "AppStoreConnectKit")
        ], linkerSettings: [.linkedLibrary("sqlite3")]),
        .target(name: "AppDabServices", dependencies: [
            "AppDabBagbutikExtensions",
            .product(name: "BagbutikCore", package: "Bagbutik"),
            .product(name: "BagbutikAppStore", package: "Bagbutik"),
            .product(name: "ConnectAccounts", package: "AppStoreConnectKit")
        ]),
        .target(name: "AppDabBagbutikExtensions", dependencies: [
            .product(name: "BagbutikAppStore", package: "Bagbutik")
        ]),
        .target(name: "AppDabKitTestSupport", dependencies: [
            "AppDabAutomation",
            "AppDabServices",
        ]),
        // Tests
        .testTarget(name: "AppDabAutomationTests", dependencies: [
            "AppDabAutomation",
            "AppDabKitTestSupport"
        ]),
        .testTarget(name: "AppDabServicesTests", dependencies: [
            "AppDabServices",
            .product(name: "BagbutikCore", package: "Bagbutik"),
            .product(name: "BagbutikAppStore", package: "Bagbutik"),
            .product(name: "ConnectAccounts", package: "AppStoreConnectKit")
        ])
    ]
)
