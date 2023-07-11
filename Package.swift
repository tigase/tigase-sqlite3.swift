// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "tigase-sqlite3.swift",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TigaseSQLite3",
            targets: ["TigaseSQLite3"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", revision: "swift-DEVELOPMENT-SNAPSHOT-2023-06-27-a")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .systemLibrary(name: "CSQLite", providers: [
            .apt(["libsqlite3-dev"]),
            .brew(["sqlite3"])
        ]),
        .macro(
            name: "TigaseSQLite3Macros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ],
            linkerSettings: [
                .unsafeFlags(["-v"])
            ]
        ),
        .testTarget(name: "TigaseSQLite3MacrosTests",
            dependencies: [
                "TigaseSQLite3Macros"
            ]
        ),
        .target(
            name: "TigaseSQLite3",
            dependencies: [
                .target(name: "CSQLite"),
                .target(name: "TigaseSQLite3Macros")
            ]
        ),
        .testTarget(
            name: "TigaseSQLite3Tests",
            dependencies: ["TigaseSQLite3"]
        ),
    ]
)
