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
//   CueExport – PowerPoint (editable, static), PDF and PNG export of the
//               rendered deck. WebKit via CueRender; writes OOXML itself.
//   CueMCP    – Cue's MCP server (tools, resources, change sets over a
//               DeckHost), the Unix-socket listener. CueCore + MCP only.
//   cue-mcp   – The tiny helper Claude starts: pipes stdio to Cue's socket.
let package = Package(
    name: "Cue",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "CueCore", targets: ["CueCore"]),
        .library(name: "CueRender", targets: ["CueRender"]),
        .library(name: "CueUI", targets: ["CueUI"]),
        .library(name: "CueImport", targets: ["CueImport"]),
        .library(name: "CueEditor", targets: ["CueEditor"]),
        .library(name: "CueMCP", targets: ["CueMCP"]),
        .library(name: "CueExport", targets: ["CueExport"]),
        .executable(name: "cue-mcp", targets: ["cue-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
    ],
    targets: [
        .target(name: "CueCore", resources: [.copy("Resources/parse5.bundle.js")]),
        .target(name: "CueRender", dependencies: ["CueCore"], resources: [.copy("Resources/JS")]),
        .target(name: "CueUI"),
        .target(name: "CueImport", dependencies: ["CueCore"]),
        .target(name: "CueEditor", dependencies: ["CueCore", "CueRender"]),
        .target(name: "CueMCP", dependencies: ["CueCore", .product(name: "MCP", package: "swift-sdk")]),
        .executableTarget(name: "cue-mcp"),
        .target(name: "CueExport", dependencies: ["CueCore", "CueRender", "CueImport"]),
        .testTarget(name: "CueCoreTests", dependencies: ["CueCore"]),
        .testTarget(name: "CueRenderTests", dependencies: ["CueRender"]),
        .testTarget(name: "CueUITests", dependencies: ["CueUI"]),
        .testTarget(name: "CueImportTests", dependencies: ["CueImport", "CueRender"]),
        .testTarget(name: "CueEditorTests", dependencies: ["CueEditor", "CueRender"]),
        .testTarget(name: "CueExportTests", dependencies: ["CueExport", "CueImport", "CueRender"]),
        .testTarget(name: "CueMCPTests", dependencies: ["CueMCP", .product(name: "MCP", package: "swift-sdk")]),
    ],
    swiftLanguageModes: [.v6]
)
