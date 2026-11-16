import AppKit

/// Scripts run the same `ControlBridge.handle` path as JSON clients, so they share
/// its validation, permission checks and acknowledged state.
extension AppDelegate {
    static let scriptKeys: Set<String> = ["scriptPointers", "scriptPointerActive", "scriptInteract", "scriptSelectedPointer", "scriptDrawingTool"]

    @objc(application:delegateHandlesKey:)
    func application(_ sender: NSApplication, delegateHandlesKey key: String) -> Bool {
        Self.scriptKeys.contains(key)
    }

    @objc var scriptPointers: [ScriptPointer] { PointerStyle.allCases.map(ScriptPointer.init) }

    @objc var scriptPointerActive: Bool {
        get { runScriptOperation(["operation": "status"])?["active"] as? Bool ?? false }
        set { runScriptOperation(["operation": newValue ? "on" : "off"]) }
    }

    @objc var scriptInteract: Bool {
        get { runScriptOperation(["operation": "status"])?["interact"] as? Bool ?? false }
        set { runScriptOperation(["operation": "interact", "enabled": newValue]) }
    }

    @objc var scriptSelectedPointer: Any? {
        get {
            (runScriptOperation(["operation": "status"])?["style"] as? String)
                .flatMap(PointerStyle.init(rawValue:)).map(ScriptPointer.init)
        }
        set {
            guard let id = (newValue as? ScriptPointer)?.uniqueID ?? newValue as? String else {
                return ScriptFailure.report("Choose a pointer, such as pointer \"Robot\" or \"robot\".")
            }
            runScriptOperation(["operation": "style", "style": id])
        }
    }

    @objc var scriptDrawingTool: OSType {
        get {
            (runScriptOperation(["operation": "status"])?["tool"] as? String).flatMap { ScriptDrawingTool.codes[$0] } ?? 0
        }
        set {
            guard let tool = ScriptDrawingTool.codes.first(where: { $0.value == newValue })?.key else {
                return ScriptFailure.report("Choose pen tool, rectangle tool, arrow tool, text tool, number tool, eraser tool or highlighter tool.")
            }
            runScriptOperation(["operation": "tool", "tool": tool])
        }
    }

    /// Returns the acknowledged state, or reports the app's rejection as a script error.
    @discardableResult
    func runScriptOperation(_ fields: [String: Any]) -> [String: Any]? {
        var request = fields
        request["version"] = ControlTransport.version
        guard let data = try? JSONSerialization.data(withJSONObject: request),
              let reply = try? JSONSerialization.jsonObject(with: control.handle(data)) as? [String: Any] else {
            ScriptFailure.report("Look Here Please could not process this command.")
            return nil
        }
        guard reply["ok"] as? Bool == true else {
            let error = reply["error"] as? [String: Any]
            ScriptFailure.report(error?["message"] as? String ?? "Look Here Please rejected this command.", code: error?["code"] as? String)
            return nil
        }
        return reply["state"] as? [String: Any]
    }
}

enum ScriptFailure {
    static let numbers = ["accessibility": 1001, "unavailable": 1002, "unknown-style": 1003, "missing-asset": 1004, "activation-failed": 1005, "disabled-style": 1006]

    static func report(_ message: String, code: String? = nil) {
        let command = NSScriptCommand.current()
        command?.scriptErrorNumber = code.flatMap { numbers[$0] } ?? 1000
        command?.scriptErrorString = message
    }
}

enum ScriptDrawingTool {
    static let codes: [String: OSType] = ["pen": fourCharacters("LkPn"), "rectangle": fourCharacters("LkRc"), "arrow": fourCharacters("LkAr"), "text": fourCharacters("LkTx"), "number": fourCharacters("LkNm"), "eraser": fourCharacters("LkEr"), "highlighter": fourCharacters("LkHi")]

    private static func fourCharacters(_ value: String) -> OSType {
        value.utf8.reduce(0) { $0 << 8 | OSType($1) }
    }
}

@objc(LHPScriptPointer)
final class ScriptPointer: NSObject {
    @objc let uniqueID: String
    @objc let name: String

    init(_ style: PointerStyle) {
        uniqueID = style.rawValue
        name = style.title
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let application = NSScriptClassDescription(for: NSApplication.self) else { return nil }
        return NSUniqueIDSpecifier(containerClassDescription: application, containerSpecifier: nil, key: "scriptPointers", uniqueID: uniqueID)
    }
}

@objc(LHPTogglePointerCommand)
final class ScriptTogglePointerCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        (NSApp.delegate as? AppDelegate)?.runScriptOperation(["operation": "toggle"])?["active"]
    }
}

@objc(LHPToggleInteractCommand)
final class ScriptToggleInteractCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let delegate = NSApp.delegate as? AppDelegate,
              let current = delegate.runScriptOperation(["operation": "status"])?["interact"] as? Bool else { return nil }
        return delegate.runScriptOperation(["operation": "interact", "enabled": !current])?["interact"]
    }
}
