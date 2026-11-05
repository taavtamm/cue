import Darwin
import Foundation

/// The small bits of POSIX the relay needs: connect, newline-split reads, full writes.
enum UnixSocket {
    static func connect(_ path: String) -> Int32? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else { close(fd); return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            _ = path.withCString { strncpy(buffer.baseAddress!.assumingMemoryBound(to: CChar.self), $0, buffer.count - 1) }
        }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        if connected == 0 { return fd }
        close(fd)
        return nil
    }

    /// Each newline-terminated line (newline included) until the stream closes.
    static func lines(from fd: Int32) -> AnySequence<Data> {
        AnySequence { () -> AnyIterator<Data> in
            var pending = Data()
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            return AnyIterator {
                while true {
                    if let newline = pending.firstIndex(of: 0x0A) {
                        let line = pending[pending.startIndex...newline]
                        pending = Data(pending[pending.index(after: newline)...])
                        return Data(line)
                    }
                    let count = read(fd, &buffer, buffer.count)
                    if count <= 0 { return nil }
                    pending.append(contentsOf: buffer[0..<count])
                }
            }
        }
    }

    /// Writes all of `data`; false if the other side has gone.
    static func write(_ data: Data, to fd: Int32) -> Bool {
        data.withUnsafeBytes { raw in
            var written = 0
            while written < raw.count {
                let result = Darwin.write(fd, raw.baseAddress! + written, raw.count - written)
                if result <= 0 { return false }
                written += result
            }
            return true
        }
    }
}

/// Just enough of a JSON-RPC message to route it: its id (as written) and method.
struct Message {
    let id: String?
    let method: String?

    init(_ line: Data) {
        let object = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any]
        method = object?["method"] as? String
        switch object?["id"] {
        case let number as NSNumber: id = number.stringValue
        case let text as String: id = "\"\(text)\""
        default: id = nil
        }
    }
}
