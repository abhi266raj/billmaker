// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BillMaker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "BillMaker",
            targets: ["BillMaker"]
        )
    ],
    targets: [
        .executableTarget(
            name: "BillMaker",
            path: "Sources/BillMaker",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BillMakerTests",
            dependencies: ["BillMaker"],
            path: "Tests/BillMakerTests"
        )
    ]
)
