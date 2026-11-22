// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BillMaker",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(
            name: "BillMaker",
            targets: ["BillMaker"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/abhi266raj/AgentAtom.git", exact: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "BillMaker",
            dependencies: [
                .product(name: "AgentAtomSource", package: "AgentAtom")
            ],
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
    ],
    swiftLanguageModes: [.v5]
)
