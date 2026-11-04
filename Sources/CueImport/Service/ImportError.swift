import Foundation

public enum ImportError: Error, LocalizedError, Equatable {
    case unsupportedType(String)
    case needsKeynote(String)
    case keynoteFailed(String)
    case keynoteTimedOut
    case automationDenied
    case wouldOverwrite(URL)
    case damaged(String)
    case empty

    public var errorDescription: String? {
        switch self {
        case .unsupportedType(let ext): "Cue can't open .\(ext) files."
        case .needsKeynote(let ext): "Opening .\(ext) files needs Keynote, which isn't installed."
        case .keynoteFailed(let message): "Keynote couldn't convert the file: \(message)"
        case .keynoteTimedOut: "Keynote didn't finish converting the file in time."
        case .automationDenied:
            "Cue isn't allowed to control Keynote. Turn it on in System Settings › Privacy & Security › Automation."
        case .wouldOverwrite(let url): "Cue won't replace “\(url.lastPathComponent)”, because Cue didn't create it."
        case .damaged(let detail): "The file looks damaged: \(detail)"
        case .empty: "The presentation has no slides."
        }
    }
}
