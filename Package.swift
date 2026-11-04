// swift-tools-version: 6.2
import PackageDescription

// Cue's testable code lives in this package. The app target (project.yml)
// is a thin shell that composes these modules into windows.
//
//   CueCore   – Foundation only. Deck model, adapters, parsing, show state.
//   CueRender – WebKit. Slide rendering, CueBridge, scheme handler, sandbox.
//   CueUI     – SwiftUI/AppKit. Shared design-system components.
let package = Package(
    name: "Cue",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "CueCore", targets: ["CueCore"]),
        .library(name: "CueRender", targets: ["CueRender"]),
        .library(name: "CueUI", targets: ["CueUI"]),
    ],
    targets: [
        .target(name: "CueCore", resources: [.copy("Resources/parse5.bundle.js")]),
        .target(name: "CueRender", dependencies: ["CueCore"], resources: [.copy("Resources/JS")]),
        .target(name: "CueUI"),
        .testTarget(name: "CueCoreTests", dependencies: ["CueCore"]),
        .testTarget(name: "CueRenderTests", dependencies: ["CueRender"]),
        .testTarget(name: "CueUITests", dependencies: ["CueUI"]),
    ],
    swiftLanguageModes: [.v6]
)
