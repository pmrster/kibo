// swift-tools-version: 6.0
import PackageDescription

// Zero external dependencies, on purpose: every dependency is a new trust root for a utility
// whose whole selling point is that it touches nothing but the text you hand it.
let package = Package(
    name: "WhoForgotToChangeLang",
    platforms: [.macOS(.v14)],
    targets: [
        // All logic, zero AppKit/SwiftUI. Fully unit-tested.
        .target(name: "WhoForgotToChangeLangCore"),
        // The SwiftUI/AppKit shell. Thin; not unit-tested.
        .executableTarget(
            name: "WhoForgotToChangeLang",
            dependencies: ["WhoForgotToChangeLangCore"]
        ),
        .testTarget(
            name: "WhoForgotToChangeLangCoreTests",
            dependencies: ["WhoForgotToChangeLangCore"]
        ),
    ]
)
