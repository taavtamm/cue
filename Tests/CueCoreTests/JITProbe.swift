import Foundation
import JavaScriptCore

/// Whether JavaScriptCore's JIT is enabled in this process. It needs the
/// `com.apple.security.cs.allow-jit` entitlement under the hardened runtime;
/// test runners don't have it, so timing budgets differ.
enum JITProbe {
    static let isAvailable: Bool = {
        guard let context = JSContext() else { return false }
        let start = Date()
        context.evaluateScript("let s = 0; for (let i = 0; i < 5000000; i++) s = (s + i) | 0; s")
        return Date().timeIntervalSince(start) < 0.03
    }()
}
