// swift-tools-version: 5.9
import PackageDescription

// Hoist — a tiny macOS menu-bar app that shows a country flag emoji,
// optionally with the country's local time. Pure Apple frameworks
// (AppKit + SwiftUI + ServiceManagement), no third-party deps.
let package = Package(
    name: "Hoist",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Hoist",
            path: "Sources/Hoist"
        ),
    ]
)
