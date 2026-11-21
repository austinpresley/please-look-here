import AppKit
import Testing
@testable import TinyHand

@Suite("Radial v9 layout and appearances")
struct RadialRenderingTests {
    private func menu(bounds: CGRect = CGRect(x: 0, y: 0, width: 1200, height: 900), mode: RadialMode = .persistent) -> RadialSession {
        RadialCatalog.make(geometry: RadialGeometry(cursor: CGPoint(x: bounds.midX, y: bounds.midY), bounds: bounds),
            state: RadialCurrentState(pointerID: "lavender", ink: .match, tool: .pen, interact: true, tapSound: false, muted: false, toolbar: true),
            favorites: RadialFavorites.defaults, pointers: (PointerStyle.builtInHands + [.laser]).map { PointerCatalog.Entry(style: $0, enabled: true, available: true) }, canUndo: true, canRedo: false, hasInk: true, mode: mode)
    }
    @Test("Every measured symbol and text line stays in its sector with outer clearance", arguments: ["root", "pointer", "color", "draw", "more"])
    func measuredBounds(level: String) {
        var session = menu()
        if level != "root", let index = session.root.firstIndex(where: { $0.id == level }) { _ = session.activate(index) }
        for index in session.items.indices {
            let item = session.items[index], layout = RadialItemLayout(session: session, index: index)
            #expect(layout.labels.count <= 2, "\(level)/\(item.title) exceeds two measured lines")
            for (text, frame) in layout.labels {
                let measured = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: layout.fontSize, weight: .medium)]).width
                if measured <= 76 { #expect(frame.width >= measured, "Standard label clipped: \(text)") }
            }
            #expect(abs(layout.icon.minY - (layout.labels.first?.1.maxY ?? 0) - 8) < 0.001)
            for frame in layout.visibleFrames {
                for x in [frame.minX, frame.maxX] { for y in [frame.minY, frame.maxY] {
                    let point = CGPoint(x: x, y: y), center = CGPoint(x: 192, y: 192)
                    #expect(RadialGeometry.distance(point, center) <= 156.001, "\(level)/\(item.title) outer corner \(point)")
                    #expect(RadialGeometry.difference(RadialGeometry.angle(point, from: center), session.angle(for: index)) <= 180 / CGFloat(session.items.count) + 0.001, "\(level)/\(item.title) sector corner \(point)")
                } }
            }
        }
    }
    @Test("Opaque colors, disabled text and selection pairs follow each appearance", arguments: [false, true])
    func palette(dark: Bool) {
        let tokens = RadialAppearance(dark: dark, opaque: true)
        #expect(tokens.background == (dark ? 0x29242D : 0xF8F5F1))
        #expect(tokens.secondary == (dark ? 0xC3B9C8 : 0x645B68))
        #expect(tokens.selection == (dark ? 0xFF9589 : 0xB6423B))
        #expect(tokens.onSelection == (dark ? 0x302736 : 0xFFFFFF))
        #expect(!tokens.usesMaterial)
        #expect(!RadialAppearance(dark: dark, contrast: true).usesMaterial)
        #expect(RadialAppearance(dark: dark).usesMaterial)
    }
    @Test("Reduce Motion retains only opening opacity")
    func motion() {
        let tokens = RadialAppearance(reduceMotion: true)
        #expect(tokens.openDuration == 0.08)
        #expect(tokens.closeDuration == 0 && tokens.hubDuration == 0 && tokens.hoverDuration == 0)
        #expect(tokens.levelDuration(back: true) == 0 && tokens.levelDuration(back: false) == 0)
        #expect(RadialAppearance().levelDuration(back: true) == 0.08)
        #expect(RadialAppearance().levelDuration(back: false) == 0.1)
    }
    @Test("List threshold applies to either usable dimension", arguments: [CGSize(width: 383, height: 900), CGSize(width: 1200, height: 383), CGSize(width: 384, height: 384)])
    func threshold(size: CGSize) {
        let session = menu(bounds: CGRect(origin: .zero, size: size))
        #expect(session.geometry.usesList == (size.width < 384 || size.height < 384))
        if session.geometry.usesList {
            #expect(session.geometry.bounds.contains(session.panelFrame))
            #expect(session.panelFrame.width <= 300)
        }
    }
    @Test("Scrollable list targets and Back share the activation state machine", arguments: [RadialMode.held, .persistent])
    func listActivation(mode: RadialMode) {
        var session = menu(bounds: CGRect(x: 0, y: 0, width: 320, height: 180), mode: mode)
        #expect(session.listLayout.maximumScroll > 0)
        let point = CGPoint(x: session.panelFrame.midX, y: session.panelFrame.maxY - 58)
        session.pointerDown(point); _ = session.pointerUp(point)
        #expect(session.group == "pointer")
        #expect(session.items.first?.isBack == true)
        #expect(session.keyboardOrder == Array(session.items.indices))
        session.scrollList(to: 10000)
        #expect(session.listScroll == session.listLayout.maximumScroll)
        session.scrollList(to: 0)
        let back = CGPoint(x: session.panelFrame.midX, y: session.panelFrame.maxY - 58)
        session.pointerDown(back); _ = session.pointerUp(back)
        #expect(session.group == nil)
    }
    @Test("Pointer-only held inspection never owns focus; keyboard transfer persists")
    func focus() {
        var held = menu(mode: .held)
        held.inspect(6, keyboard: false); #expect(!held.ownsFocus)
        _ = held.key(.tab); #expect(held.ownsFocus && held.keyboard)
        held.move(held.geometry.center); #expect(held.ownsFocus && !held.keyboard)
        #expect(menu().ownsFocus)
    }
    @Test("The open action is unassigned by default and participates in shortcut storage")
    func shortcut() {
        #expect(PresentationAction.quickControls.title == "Open Quick controls")
        #expect(!PresentationAction.quickControls.drawOnly)
        #expect(PresentationAction.allCases.contains(.quickControls))
        // Defaults are isolated by run-tests.sh; the existing ShortcutTests
        // exercise round trips and reset for every PresentationAction.
    }
    @Test("All catalog SF Symbols exist on the local platform")
    func symbols() {
        let session = menu()
        for item in session.root + session.groups.values.flatMap({ $0 }) where item.style == nil {
            #expect(NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil) != nil, "Missing \(item.symbol)")
        }
    }
}

@Suite struct RadialLongNameLayoutTests {
    @Test func arbitraryMissingPointerNamesKeepTwoLinesAndNativeTypeInsideEverySector() {
        let items = (0..<8).map { RadialItem(id: "missing-\($0)", role: .pointerFavorite("missing-\($0)"), title: "A very long custom presentation pointer name \($0)", symbol: "questionmark", enabled: false, style: .glove) }
        let session = RadialSession(geometry: RadialGeometry(cursor: CGPoint(x: 500, y: 500), bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000)), root: [RadialItem(id: "pointer", role: .root(.pointer), title: "Pointer", symbol: "hand.point.up", group: "pointer")], groups: ["pointer": items])
        var child = session; _ = child.activate(0)
        for index in child.items.indices {
            let layout = RadialItemLayout(session: child, index: index)
            #expect(layout.labels.count <= 2 && layout.fontSize == 12)
            for (_, frame) in layout.labels {
                #expect(frame.width > 0 && frame.width <= 76)
                for x in [frame.minX, frame.maxX] { for y in [frame.minY, frame.maxY] {
                    let point = CGPoint(x: x, y: y), center = CGPoint(x: 192, y: 192)
                    #expect(RadialGeometry.distance(point, center) <= 156.001)
                    #expect(RadialGeometry.difference(RadialGeometry.angle(point, from: center), child.angle(for: index)) <= 180 / CGFloat(child.items.count) + 0.001)
                } }
            }
        }
    }
}

@Suite("Quick controls semantic collision regressions") @MainActor
struct RadialSemanticCollisionTests {
    private func menu(id: String, list: Bool) -> RadialSession {
        let bounds = CGRect(x: 0, y: 0, width: list ? 320 : 1200, height: 900)
        var favorites = RadialFavorites.defaults; favorites[0] = id
        let catalog = RadialCatalog.make(geometry: RadialGeometry(cursor: CGPoint(x: bounds.midX, y: bounds.midY), bounds: bounds),
            state: RadialCurrentState(pointerID: id, ink: .black, tool: .arrow, interact: true, tapSound: true, muted: true, toolbar: true),
            favorites: favorites, pointers: [], canUndo: true, canRedo: true, hasInk: true, mode: .persistent)
        // Storage rejects these reserved IDs. Inject them at the session seam
        // too, so presentation and activation cannot rely on that validation.
        guard !RadialFavorites.valid(favorites) else { return catalog }
        var groups = catalog.groups
        groups["pointer"]?[3] = RadialItem(id: id, role: .pointerFavorite(id), title: id, symbol: "questionmark", selected: true, enabled: false,
            request: ["version": 1, "operation": "style", "style": id], reason: "Pointer unavailable", subtitle: "Current pointer")
        return RadialSession(geometry: catalog.geometry, root: catalog.root, groups: groups, mode: .persistent)
    }

    @Test(arguments: ["pointer", "color", "draw", "interact", "clear", "undo", "redo", "screenshot", "more", "all", "back", "match", "sound", "mute", "toolbar"])
    func wheelFavoritesKeepTheirOwnArtworkGeometryAndState(id: String) throws {
        var model = menu(id: id, list: false); _ = model.activate(0)
        let index = 4, item = model.items[index]
        #expect(item.id == id && !item.enabled && item.selected)
        #expect(!item.isBack && !item.opensBrowser)
        #expect(RadialVisualIdentity.resolve(item, pointer: .glove, ink: .black, tool: .arrow) == .symbol("questionmark"))
        let layout = RadialItemLayout(session: model, index: index)
        #expect(layout.icon.width == 22 && layout.badge == nil && layout.showsCheck)
        let center = RadialGeometry.point(angle: model.angle(for: index), radius: RadialGeometry.rootRadius, center: CGPoint(x: 192, y: 192))
        #expect(abs(layout.icon.midX - center.x) < 0.001)
        #expect(abs(layout.icon.maxY - (center.y + (22 + 8 + 15) / 2)) < 0.001)
        model.inspect(index, keyboard: true)
        #expect(model.pendingCopy.title == id && model.pendingCopy.subtitle == "Pointer unavailable")
        #expect(model.activate(index) == nil && model.group == "pointer" && !model.closed)
        model.updateCurrent(RadialCurrentState(pointerID: "other", ink: .match, tool: .pen, interact: false, tapSound: false, muted: false, toolbar: false))
        #expect(!model.items[index].selected && !RadialItemLayout(session: model, index: index).showsCheck)
        #expect(RadialVisualIdentity.rowState(model.items[index]).isEmpty)
    }

    @Test(arguments: ["pointer", "color", "draw", "interact", "clear", "undo", "redo", "screenshot", "more", "all", "back"])
    func listFavoritesKeepTheirOwnLabelCheckAndAccessibility(id: String) throws {
        var model = menu(id: id, list: true); _ = model.activate(0)
        let index = 4, item = model.items[index]
        #expect(RadialVisualIdentity.resolve(item, pointer: .glove, ink: .black, tool: .arrow, list: true) == .symbol("questionmark"))
        #expect(RadialVisualIdentity.rowState(item) == "✓")
        let list = QuickControlsList(frame: CGRect(origin: .zero, size: model.panelFrame.size))
        list.update(model, tokens: RadialAppearance()); list.layoutSubtreeIfNeeded()
        let scroll = try #require(list.subviews.compactMap { $0 as? NSScrollView }.first)
        let table = try #require(scroll.documentView as? NSTableView)
        let cell = try #require(table.view(atColumn: 0, row: index, makeIfNecessary: true) as? NSTableCellView)
        #expect(cell.textField?.stringValue == id)
        #expect(cell.subviews.compactMap { $0 as? NSTextField }.map(\.stringValue).contains("✓"))
        let ax = RadialAccessibility()
        ax.update(session: model, view: list, frames: [], currentSession: { model }, activate: { _ in Issue.record("Unavailable favorite activated"); return true }, inspect: { _ in }, back: {})
        let element = try #require(list.accessibilityChildren()?[index] as? RadialAccessibility.Item)
        #expect(element.accessibilityLabel() == id && element.accessibilityRole() == .checkBox)
        #expect((element.accessibilityValue() as? NSNumber)?.boolValue == true)
        #expect(!element.accessibilityPerformPress())
        #expect(model.activate(index) == nil && model.group == "pointer" && !model.closed)
        model.updateCurrent(RadialCurrentState(pointerID: "other", ink: .match, tool: .pen, interact: false, tapSound: false, muted: false, toolbar: false))
        list.update(model, tokens: RadialAppearance())
        #expect(RadialVisualIdentity.rowState(model.items[index]).isEmpty)
        #expect(cell.subviews.compactMap { $0 as? NSTextField }.allSatisfy { !["ON", "OFF", "✓", "›"].contains($0.stringValue) })
    }
}
