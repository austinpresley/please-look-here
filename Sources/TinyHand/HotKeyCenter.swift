import AppKit
import Carbon.HIToolbox

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private struct Handler { let press: () -> Void; let release: (() -> Void)? }
    private var handlers: [UInt32: Handler] = [:]
    private var held = Set<UInt32>()
    private var blocked = Set<UInt32>()
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {
        let specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        _ = specs.withUnsafeBufferPointer { specs in
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                HotKeyCenter.shared.dispatch(hkID.id, released: GetEventKind(event) == UInt32(kEventHotKeyReleased))
                return noErr
            },
            2,
            specs.baseAddress,
            nil,
            &eventHandler
        )
        }
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void, onRelease: (() -> Void)? = nil) -> UInt32? {
        let id = nextID
        nextID += 1
        handlers[id] = Handler(press: action, release: onRelease)
        if onRelease != nil && CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(keyCode)) { blocked.insert(id) }

        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x54484B59), id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hkID,
            GetApplicationEventTarget(),
            // Shared registrations can succeed without receiving events when
            // another app owns the key. Exclusive registration reports a conflict.
            OptionBits(kEventHotKeyExclusive),
            &ref
        )
        guard status == noErr, let ref = ref else {
            handlers[id] = nil
            blocked.remove(id)
            return nil
        }
        refs[id] = ref
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
        handlers[id] = nil
        held.remove(id); blocked.remove(id)
    }
    private func dispatch(_ id: UInt32, released: Bool) {
        guard let handler = handlers[id] else { return }
        if released {
            blocked.remove(id)
            if held.remove(id) != nil { handler.release?() }
        } else if !blocked.contains(id) {
            if handler.release != nil && !held.insert(id).inserted { return }
            handler.press()
        }
    }
}

/// Keeps successful commands registered when another command conflicts. Native
/// registration is injected so conflict and rollback tests never seize real keys.
final class HotKeyBindings {
    struct Binding {
        let command: String
        let identity: String
        let shortcut: Shortcut
        let press: () -> Void
        let release: (() -> Void)?
        let onRemove: () -> Void
        init(_ command: String, identity: String? = nil, shortcut: Shortcut,
             press: @escaping () -> Void, release: (() -> Void)? = nil, onRemove: @escaping () -> Void = {}) {
            self.command = command; self.identity = identity ?? command
            self.shortcut = shortcut; self.press = press; self.release = release; self.onRemove = onRemove
        }
    }
    private struct Registered { let binding: Binding; let id: UInt32 }
    private var registered: [String: Registered] = [:]
    private(set) var failures: [String: Shortcut] = [:]
    private let register: (Binding) -> UInt32?
    private let unregister: (UInt32) -> Void
    var count: Int { registered.count }

    init(register: @escaping (Binding) -> UInt32? = {
        HotKeyCenter.shared.register(keyCode: $0.shortcut.keyCode, modifiers: $0.shortcut.modifiers,
                                     action: $0.press, onRelease: $0.release)
    }, unregister: @escaping (UInt32) -> Void = { HotKeyCenter.shared.unregister($0) }) {
        self.register = register; self.unregister = unregister
    }
    func remove(_ command: String) {
        if let old = registered.removeValue(forKey: command) { unregister(old.id); old.binding.onRemove() }
        failures[command] = nil
    }
    func removeAll(preservingFailures: Bool = false) {
        let retained = failures
        for command in Array(registered.keys) { remove(command) }
        failures = preservingFailures ? retained : [:]
    }
    @discardableResult
    func update(_ bindings: [Binding], assignments: [String: Shortcut]? = nil) -> Bool {
        let desired = Dictionary(uniqueKeysWithValues: bindings.map { ($0.command, $0) })
        for (command, old) in registered {
            guard let new = desired[command], new.identity == old.binding.identity,
                  new.shortcut == old.binding.shortcut else { remove(command); continue }
        }
        // Context-inactive commands keep their diagnostic until their saved
        // assignment changes or a later native registration succeeds.
        let saved = assignments ?? desired.mapValues(\.shortcut)
        failures = failures.filter { saved[$0.key] == $0.value }
        for binding in bindings where registered[binding.command] == nil {
            if let id = register(binding) {
                registered[binding.command] = Registered(binding: binding, id: id)
                failures[binding.command] = nil
            } else { failures[binding.command] = binding.shortcut }
        }
        return failures.isEmpty
    }
}
