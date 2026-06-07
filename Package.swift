// swift-tools-version: 5.9
//
// This Package.swift exists so the *library* code in `Sources/VKRConferencing`
// (everything that isn't UIKit/SwiftUI App glue) can be built and tested
// from the command line without Xcode.
//
// To run the full SwiftUI application you generate the Xcode project from
// `project.yml` with XcodeGen:
//
//     brew install xcodegen
//     xcodegen
//     open VKRConferencing.xcodeproj
//
// XcodeGen wires in the WebRTC package, the entitlements and the Info.plist —
// none of which fit cleanly into SwiftPM for an iOS application target.

import PackageDescription

let package = Package(
    name: "VKRConferencing",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "VKRConferencingCore", targets: ["VKRConferencingCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VKRConferencingCore",
            path: "Sources/VKRConferencing",
            exclude: [
                "App",
                "UI",
                "PlatformAPIs",
                "MediaStack"
            ],
            sources: [
                "BusinessLogic"
            ]
        ),
        .testTarget(
            name: "VKRConferencingTests",
            dependencies: ["VKRConferencingCore"],
            path: "Tests/VKRConferencingTests"
        )
    ]
)
