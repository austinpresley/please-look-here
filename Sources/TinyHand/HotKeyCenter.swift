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
