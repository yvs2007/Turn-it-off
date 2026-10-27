// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AntiDistractDomain",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "AntiDistractDomain", targets: ["AntiDistractDomain"])
    ],
    targets: [
        // Pure Swift + Foundation only. No FamilyControls / ManagedSettings / DeviceActivity
        // imports live here, which is what keeps this layer unit-testable off-device.
        .target(name: "AntiDistractDomain"),
        .testTarget(
            name: "AntiDistractDomainTests",
            dependencies: ["AntiDistractDomain"]
        )
    ]
)
