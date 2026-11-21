import AppKit

final class RadialAccessibility {
    struct Identity: Equatable {
        let generation: UUID
        let level: String
        let itemID: String
        let slot: Int?
        let role: RadialItemRole?
    }
    final class Item: NSAccessibilityElement {
        var identity: Identity?
        var valid: () -> Bool = { false }
        var viewportVisible = true
        var press: (() -> Bool)?
        var focus: (() -> Void)?
        override func isAccessibilityElement() -> Bool { valid() }
        override func isAccessibilityEnabled() -> Bool { valid() && super.isAccessibilityEnabled() }
        override func isAccessibilityHidden() -> Bool { !valid() || !viewportVisible }
        override func accessibilityPerformPress() -> Bool { valid() && (press?() ?? false) }
        override func setAccessibilityFocused(_ focused: Bool) {
            guard valid() else { return }
            super.setAccessibilityFocused(focused)
            if focused { focus?() }
        }
        func invalidate() {
            valid = { false }; press = nil; focus = nil
            setAccessibilityParent(nil); setAccessibilityFrame(.zero)
        }
    }
    private var elements: [Item] = []
    private var hub: Item?
    private weak var owner: NSView?
    private var usesList = false
    private var generation: UUID?, epoch = UUID()
    private var level = "", lastFocus = "", lastAnnouncement = ""
    func update(session: RadialSession, view: NSView, frames: [CGRect], visibility: [Bool] = [], currentSession: @escaping () -> RadialSession?, activate: @escaping (Int) -> Bool, inspect: @escaping (Int) -> Void, back: @escaping () -> Void) {
        let next = session.group ?? "root"
        usesList = session.geometry.usesList
        if generation != session.generation || level != next || owner !== view {
            invalidateChildren()
            generation = session.generation; level = next; lastFocus = ""; owner = view
            let epoch = self.epoch
            func live(_ identity: Identity) -> RadialSession? {
                guard let current = currentSession(), !current.closed, current.generation == identity.generation,
                      (current.group ?? "root") == identity.level else { return nil }
                return current
            }
            elements = session.items.enumerated().map { index, item in
                let identity = Identity(generation: session.generation, level: next, itemID: item.id, slot: index, role: item.role)
                let element = Item(); element.identity = identity
                element.setAccessibilityParent(view)
                func liveItem() -> RadialItem? {
                    guard let current = live(identity), let slot = identity.slot,
                          current.items.indices.contains(slot), current.items[slot].id == identity.itemID,
                          current.items[slot].role == identity.role else { return nil }
                    return current.items[slot]
                }
                element.valid = { [weak self] in self?.epoch == epoch && liveItem() != nil }
                element.press = {
                    guard liveItem()?.enabled == true else { return false }
                    return activate(index)
                }
                element.focus = {
                    guard liveItem() != nil else { return }
                    inspect(index)
                }
                return element
            }
            let hub = Item(), identity = Identity(generation: session.generation, level: next, itemID: "hub", slot: nil, role: nil)
            hub.identity = identity; hub.setAccessibilityParent(view); hub.setAccessibilityRole(.menuItem)
            hub.valid = { [weak self] in self?.epoch == epoch && live(identity) != nil }
            hub.press = { back(); return true }; self.hub = hub
            view.setAccessibilityChildren(session.geometry.usesList ? elements : elements + [hub])
            announce(session.group == nil ? "Quick controls" : session.title)
        }
        view.setAccessibilityLabel(session.title)
        for (index, element) in elements.enumerated() {
            let item = session.items[index]
            let check = item.role.isCheckable
            element.setAccessibilityRole(check ? .checkBox : .menuItem)
            element.setAccessibilityIdentifier("quick-controls-\(next)-\(item.id)")
            element.setAccessibilityLabel(item.isBack ? "Back to Quick controls" : item.title)
            element.setAccessibilityEnabled(item.enabled)
            element.setAccessibilityHelp([item.enabled ? item.subtitle : item.reason, item.accessibilityDetail, item.role.opensSubmenu ? "Opens submenu" : ""].filter { !$0.isEmpty }.joined(separator: ". "))
            element.setAccessibilityValue(check ? NSNumber(value: item.selected) : nil)
            if item.role.opensSubmenu { element.setAccessibilityExpanded(false) }
        }
        refreshFrames(view: view, frames: frames, visibility: visibility)
        hub?.setAccessibilityLabel(session.group == nil ? "Close Quick controls" : "Back to Quick controls")
        if let window = view.window { hub?.setAccessibilityFrame(window.convertToScreen(view.convert(CGRect(x: view.bounds.midX - 56, y: view.bounds.midY - 56, width: 112, height: 112), to: nil))) }
        let focusKey = "\(next)/\(session.highlighted ?? -1)/\(session.ownsFocus)"
        if session.ownsFocus, focusKey != lastFocus {
            lastFocus = focusKey
            let target: Any = session.highlighted.flatMap { elements.indices.contains($0) ? elements[$0] : nil } ?? view
            NSAccessibility.post(element: target, notification: .focusedUIElementChanged)
        }
        if let item = session.inspected, !item.enabled { announce("\(item.title), unavailable. \(item.reason)") }
    }
    func refreshFrames(view: NSView, frames: [CGRect], visibility: [Bool] = []) {
        guard owner === view else { return }
        for (index, element) in elements.enumerated() {
            element.viewportVisible = visibility.indices.contains(index) ? visibility[index] : true
            if frames.indices.contains(index), let window = view.window {
                element.setAccessibilityFrame(window.convertToScreen(view.convert(frames[index], to: nil)))
            } else { element.setAccessibilityFrame(.zero) }
        }
        var visible: [NSAccessibilityElement] = elements.filter { !$0.isAccessibilityHidden() }
        if !usesList, let hub, !hub.isAccessibilityHidden() { visible.append(hub) }
        view.setAccessibilityVisibleChildren(visible)
    }
    private func invalidateChildren() {
        epoch = UUID(); elements.forEach { $0.invalidate() }; hub?.invalidate()
        owner?.setAccessibilityChildren([]); owner?.setAccessibilityVisibleChildren([]); elements = []; hub = nil
    }
    func reset() { invalidateChildren(); owner = nil; generation = nil; level = ""; lastFocus = ""; lastAnnouncement = "" }
    func announce(_ message: String) {
        guard !message.isEmpty, message != lastAnnouncement else { return }; lastAnnouncement = message
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }
}
