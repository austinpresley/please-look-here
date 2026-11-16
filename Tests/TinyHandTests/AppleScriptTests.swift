import AppKit
import Testing
@testable import TinyHand

@Suite struct AppleScriptTests {
    private func dictionary() throws -> XMLDocument {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("assets/LookHerePlease.sdef")
        return try XMLDocument(contentsOf: url, options: [])
    }

    @Test func dictionaryKeysAndClassesExist() throws {
        let document = try dictionary()
        let keys = try document.nodes(forXPath: "//class[@name='application']//cocoa/@key").compactMap(\.stringValue)
        #expect(Set(keys) == AppDelegate.scriptKeys)
        for key in keys {
            #expect(AppDelegate.instancesRespond(to: NSSelectorFromString(key)), "missing getter for \(key)")
        }
        for name in try document.nodes(forXPath: "//cocoa/@class").compactMap(\.stringValue) where name != "NSApplication" {
            #expect(NSClassFromString(name) != nil, "missing class \(name)")
        }
    }

    @Test func everyDrawingToolHasAnEnumerator() throws {
        let codes = try dictionary().nodes(forXPath: "//enumerator/@code").compactMap(\.stringValue)
        #expect(codes.count == DrawingTool.allCases.count)
        #expect(Set(ScriptDrawingTool.codes.keys) == Set(DrawingTool.allCases.map(\.rawValue)))
        for code in codes {
            #expect(ScriptDrawingTool.codes.values.contains(code.utf8.reduce(0) { $0 << 8 | OSType($1) }), "unmapped \(code)")
        }
    }

    @Test func protocolErrorsHaveDistinctScriptNumbers() {
        #expect(Set(ScriptFailure.numbers.values).count == ScriptFailure.numbers.count)
        #expect(!ScriptFailure.numbers.values.contains(1000))
    }
}
