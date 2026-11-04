import Foundation

public enum ZipError: Error, Equatable, LocalizedError {
    case notAZip
    case truncated
    case multiDisk
    case badLocalHeader(String)
    case missingEntry(String)
    case encrypted(String)
    case unsupportedMethod(UInt16, String)
    case checksumMismatch(String)
    case inflateFailed(String)
    case notText(String)

    public var errorDescription: String? {
        switch self {
        case .notAZip: "The file isn't a ZIP archive."
        case .truncated: "The file is cut short."
        case .multiDisk: "Split archives aren't supported."
        case .badLocalHeader(let path): "The archive entry “\(path)” is damaged."
        case .missingEntry(let path): "The archive has no “\(path)”."
        case .encrypted(let path): "“\(path)” is password-protected."
        case .unsupportedMethod(let method, let path): "“\(path)” uses compression method \(method), which Cue can't read."
        case .checksumMismatch(let path): "“\(path)” failed its checksum."
        case .inflateFailed(let path): "“\(path)” couldn't be decompressed."
        case .notText(let path): "“\(path)” isn't UTF-8 text."
        }
    }
}
