import Foundation

/// Runs an AppleScript through /usr/bin/osascript with a time limit.
enum OSAScriptRunner {
    struct Result {
        let status: Int32
        let errorText: String
    }

    static func run(_ script: String, arguments: [String], timeout: Duration) async throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"] + arguments
        let input = Pipe(), errors = Pipe()
        process.standardInput = input
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice

        return try await withThrowingTaskGroup(of: Result?.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Result?, any Error>) in
                    process.terminationHandler = { finished in
                        let text = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                        continuation.resume(returning: Result(status: finished.terminationStatus, errorText: text))
                    }
                    do {
                        try process.run()
                        input.fileHandleForWriting.write(Data(script.utf8))
                        try? input.fileHandleForWriting.close()
                    } catch {
                        process.terminationHandler = nil
                        continuation.resume(throwing: error)
                    }
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            let first = try await group.next() ?? nil
            group.cancelAll()
            guard let first else {
                process.terminate()
                throw ImportError.keynoteTimedOut
            }
            return first
        }
    }
}
