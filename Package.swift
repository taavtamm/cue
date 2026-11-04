// swift-tools-version: 6.2
import PackageDescription

// Cue's testable code lives in this package. The app target (project.yml)
// is a thin shell that composes these modules into windows.
//
//   CueCore   – Foundation only. Deck model, adapters, parsing, show state.
//   CueRender – WebKit. Slide rendering, CueBridge, scheme handler, sandbox.
//   CueUI     – SwiftUI/AppKit. Shared design-system components.
//   CueImport – Foundation, CoreGraphics, ImageIO. PowerPoint, Keynote and PDF
//               import into Cue-convention HTML decks. No AppKit.
//   CueEditor – The editor's state and logic: selection, inspector values,
//               timeline, thumbnails. Views live in the app target.
let package = Package(
    name: "Cue",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "CueCore", targets: ["CueCore"]),
        .library(name: "CueRender", targets: ["CueRender"]),
        .library(name: "CueUI", targets: ["CueUI"]),
        .library(name: "CueImport", targets: ["CueImport"]),
        .library(name: "CueEditor", targets: ["CueEditor"]),
    ],
    targets: [
        .target(name: "CueCore", resources: [.copy("Resources/parse5.bundle.js")]),
        .target(name: "CueRender", dependencies: ["CueCore"], resources: [.copy("Resources/JS")]),
        .target(name: "CueUI"),
        .target(name: "CueImport", dependencies: ["CueCore"]),
        .target(name: "CueEditor", dependencies: ["CueCore", "CueRender"]),
        .testTarget(name: "CueCoreTests", dependencies: ["CueCore"]),
        .testTarget(name: "CueRenderTests", dependencies: ["CueRender"]),
        .testTarget(name: "CueUITests", dependencies: ["CueUI"]),
        .testTarget(name: "CueImportTests", dependencies: ["CueImport", "CueRender"]),
        .testTarget(name: "CueEditorTests", dependencies: ["CueEditor", "CueRender"]),
    ],
    swiftLanguageModes: [.v6]
)
