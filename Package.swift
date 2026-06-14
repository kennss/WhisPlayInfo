// swift-tools-version: 6.1
//
//  File:      Package.swift
//  Created:   2026-06-08
//  Updated:   2026-06-14
//  Developer: Kennt Kim / Calida Lab
//  Overview:  SwiftPM manifest for SiliconScope. Builds CIOReport (private-API C
//             shim), SiliconScopeCore (sudoless data layer, no UI), sscope-cli
//             (verification), and the SiliconScope SwiftUI app.
//  Notes:     IOReport has no SDK stub, so the final binary links with
//             -undefined dynamic_lookup; symbols resolve at runtime via dyld.
//
import PackageDescription

let package = Package(
    name: "SiliconScope",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SiliconScopeCore", targets: ["SiliconScopeCore"]),
        .executable(name: "sscope-cli", targets: ["sscope-cli"]),
        .executable(name: "SiliconScope", targets: ["SiliconScope"]),
    ],
    targets: [
        // Private IOReport declarations exposed to Swift.
        .target(name: "CIOReport"),

        // Sudoless data layer. Must NOT import SwiftUI.
        .target(
            name: "SiliconScopeCore",
            dependencies: ["CIOReport"]
        ),

        // Terminal verification tool for the data layer.
        .executableTarget(
            name: "sscope-cli",
            dependencies: ["SiliconScopeCore"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-undefined", "-Xlinker", "dynamic_lookup"]),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("IOKit"),
            ]
        ),

        // SwiftUI app (menu bar + full window). Runs via `xcrun swift run SiliconScope`.
        .executableTarget(
            name: "SiliconScope",
            dependencies: ["SiliconScopeCore"],
            resources: [.process("Resources")],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-undefined", "-Xlinker", "dynamic_lookup"]),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
