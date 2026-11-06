// swift-tools-version: 5.9
import PackageDescription

// Reuses production Swift files verbatim. UI/PhotoKit/Vision are tested on macOS CI.
let package = Package(
    name: "OrgaIA-Core-Validation",
    products: [.library(name: "OrgaIA", targets: ["OrgaIA"])],
    targets: [
        .target(name: "OrgaIA"),
        .testTarget(name: "OrgaIATests", dependencies: ["OrgaIA"])
    ]
)
