import Testing
@testable import CueCore

@Suite("Inline style declarations")
struct StyleDeclarationsTests {
    private func set(_ style: String, _ property: String, _ value: String?) throws -> String {
        let patches = StyleDeclarations(style).sourcePatches(setting: property, to: value, base: 0)
        return try SourceEdit(patches).apply(to: style).text
    }

    @Test func changesOnlyTheValue() throws {
        #expect(try set("color: red;  margin:0", "color", "blue") == "color: blue;  margin:0")
        #expect(try set("COLOR : red", "color", "blue") == "COLOR : blue")
    }

    @Test func addsWithTheFileSeparatorStyle() throws {
        #expect(try set("margin: 0;", "color", "red") == "margin: 0; color: red;")
        #expect(try set("margin: 0", "color", "red") == "margin: 0; color: red")
        #expect(try set("", "color", "red") == "color: red")
    }

    @Test func removesCleanly() throws {
        #expect(try set("color: red; margin: 0", "color", nil) == "margin: 0")
        #expect(try set("margin: 0; color: red", "color", nil) == "margin: 0")
        #expect(try set("color: red", "color", nil) == "")
    }

    @Test func entitiesAndStringsDoNotSplitDeclarations() throws {
        let style = "font-family: &quot;Inter; Display&quot;, sans-serif; color: red"
        #expect(try set(style, "color", "blue") == "font-family: &quot;Inter; Display&quot;, sans-serif; color: blue")
        let url = "background: url('a;b.png'); color: red"
        #expect(try set(url, "background", "none") == "background: none; color: red")
    }
}
