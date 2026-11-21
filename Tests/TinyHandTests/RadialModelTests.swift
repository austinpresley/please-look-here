import Foundation
import Testing
@testable import TinyHand

@Suite struct RadialModelTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1600, height: 1200)
    private var current: RadialCurrentState {
        RadialCurrentState(pointerID: "lavender", ink: .match, tool: .pen, interact: false, tapSound: false, muted: false, toolbar: true)
    }
    private func session(_ mode: RadialMode = .held, at point: CGPoint = CGPoint(x: 800, y: 600), bounds: CGRect? = nil,
                         disabled: Set<String> = [], missing: Set<String> = [], favorites: [String] = RadialFavorites.defaults) -> RadialSession {
        RadialCatalog.make(geometry: RadialGeometry(cursor: point, bounds: bounds ?? self.bounds), state: current, favorites: favorites,
            pointers: PointerStyle.builtInHands.map { PointerCatalog.Entry(style: $0, enabled: !disabled.contains($0.rawValue), available: !missing.contains($0.rawValue)) } + [PointerCatalog.Entry(style: .laser, enabled: true, available: true)],
            canUndo: true, canRedo: false, hasInk: true, mode: mode)
    }
    private func p(_ s: RadialSession, _ angle: CGFloat, _ radius: CGFloat = 100) -> CGPoint {
        RadialGeometry.point(angle: angle, radius: radius, center: s.geometry.center)
    }
    private func child(_ name: String, mode: RadialMode = .persistent) -> RadialSession {
        var s = session(mode)
        _ = s.activate(s.root.firstIndex { $0.id == name }!)
        return s
    }

    @Test(arguments: ["clear", "undo", "redo"])
    func historyRefreshNeverEnablesMissingFavoriteWithCommandID(id: String) throws {
        var favorites = RadialFavorites.defaults; favorites[0] = id
        for enabled in [false, true] {
            var model = session(.persistent, favorites: favorites)
            model.updatePointers([])
            model.updateHistory(canUndo: enabled, canRedo: enabled, hasInk: enabled)
            #expect(model.root[3].enabled == enabled && model.root[6].enabled == enabled)
            #expect(model.groups["more"]?[0].enabled == enabled)
            _ = model.activate(0)
            let slot = try #require(model.items.firstIndex { $0.id == id })
            #expect(!model.items[slot].enabled && model.items[slot].reason == "Pointer unavailable")
            #expect(model.activate(slot) == nil && !model.closed)
        }
    }


    @Test func historyRefreshUpdatesOnlyValidatedCatalogSlots() {
        let original = session(.persistent)
        let collision = RadialItem(id: "undo", role: .pointerFavorite("undo"), title: "Missing undo", symbol: "questionmark", enabled: false, request: ["operation": "style", "style": "undo"])
        var root = original.root, groups = original.groups
        root[3] = collision
        root.append(collision)
        groups["more"]?[0] = collision
        groups["draw"]?.append(collision)
        var model = RadialSession(geometry: original.geometry, root: root, groups: groups)
        model.updateHistory(canUndo: true, canRedo: true, hasInk: true)
        #expect(!model.root[3].enabled && !model.root.last!.enabled)
        #expect(model.groups["more"]?.first?.enabled == false)
        #expect(model.groups["draw"]?.last?.enabled == false)
        #expect(model.root[6].enabled)
    }


    @Test func pointerPressCannotSlideBetweenSlotsWithTheSameID() {
        var model = RadialSession(geometry: session().geometry,
            root: [RadialItem(id: "shared", role: .root(.undo), title: "First", symbol: "circle", request: ["operation": "undo"]),
                   RadialItem(id: "shared", role: .more(.redo), title: "Second", symbol: "circle", request: ["operation": "redo"])], groups: [:], mode: .persistent)
        model.pointerDown(p(model, 0))
        #expect(model.pointerUp(p(model, 180)) == nil && !model.closed)
    }

    @Test func fixedMapsContainEveryChoiceWithoutPaging() {
        let root = session()
        #expect(root.root.map(\.id) == ["pointer", "color", "draw", "clear", "interact", "screenshot", "undo", "more"])
        let pointer = child("pointer")
        #expect((0..<8).map { index in pointer.items[RadialGeometry.sector(angle: CGFloat(index) * 45, count: 8, firstAngle: pointer.firstAngle)].id } == ["glove", "lavender", "coral", "plush", "back", "robot", "laser", "all"])
        #expect(child("draw").items.map(\.id) == ["back", "pen", "highlighter", "rectangle", "arrow", "text", "number", "eraser"])
        #expect(child("color").items.map(\.id) == ["back"] + InkChoice.allCases.map(\.rawValue))
        #expect(child("more").items.map(\.id) == ["back", "redo", "sound", "mute", "toolbar", "settings", "off"])
    }
    @Test(arguments: ["root", "pointer", "color", "draw", "more"])
    func everyHalfOpenBoundaryTracksWithoutHoles(_ level: String) {
        let template = level == "root" ? session(.persistent) : child(level)
        let count = template.items.count, width = 360 / CGFloat(count)
        for i in 0..<count {
            let boundary = RadialGeometry.normalize(template.angle(for: i) + width / 2)
            for (delta, expected) in [(CGFloat(-0.00001), i), (0, (i + 1) % count), (0.00001, (i + 1) % count)] {
                #expect(RadialGeometry.sector(angle: boundary + delta, count: count, firstAngle: template.firstAngle) == expected)
                var s = template
                s.move(p(s, boundary + delta))
                #expect(s.highlighted == expected)
            }
        }
    }
    @Test func moreFormerFloatingPointHolesHaveClockwiseOwners() {
        for (a, id) in [(CGFloat(315), "toolbar"), (135 + 1.5 * 360 / 7, "sound")] {
            var s = child("more")
            s.move(p(s, a))
            #expect(s.inspected?.id == id)
        }
    }
    @Test func acquisitionRetentionHysteresisAndNeutral() {
        var s = session(.persistent)
        s.move(p(s, 135, 71.999)); #expect(s.highlighted == nil)
        s.move(p(s, 135, 72)); #expect(s.candidate?.id == "clear")
        s.move(p(s, 135, 64)); #expect(s.candidate?.id == "clear")
        s.move(p(s, 135, 63.999)); #expect(s.candidate == nil)
        s.move(p(s, 135, 70)); #expect(s.highlighted == nil)
        s.move(p(s, 135, 72)); s.move(p(s, 161.5)); #expect(s.inspected?.id == "clear")
        s.move(p(s, 161.5001)); #expect(s.inspected?.id == "interact")
        s.move(s.geometry.center); #expect(s.candidate == nil)
        s.move(p(s, 157.5)); #expect(s.inspected?.id == "interact") // no old hysteresis
    }
    @Test func entryConsumesCoalescedEventAndStraightContinuationWorks() {
        var s = session()
        let entry = p(s, 0, 260)
        s.move(entry)
        #expect(s.group == "pointer" && s.geometry.center == entry && s.highlighted == nil)
        var immediateRelease = s
        #expect(immediateRelease.release() == nil && immediateRelease.closed)
        s.move(entry); #expect(s.highlighted == nil)
        s.move(p(s, 0, 71.999)); #expect(s.candidate == nil)
        s.move(p(s, 0, 72)); #expect(s.candidate?.id == "glove")
        #expect(s.release()?.id == "glove")
        #expect(s.release() == nil && s.activate(1) == nil)
    }
    @Test func groupReleaseBeforeEntryAndNeutralReleaseCancel() {
        for radius: CGFloat in [0, 52, 72, 111.999] {
            var s = session(); s.move(p(s, 0, radius))
            #expect(s.group == nil && s.release() == nil && s.closed)
        }
        var s = child("draw", mode: .held)
        s.move(s.geometry.center)
        #expect(s.group == "draw" && s.release() == nil)
    }
    @Test func explicitBackConsumesEventAndRequiresParentNeutral() {
        var s = session(); let parent = s.geometry.center
        s.move(p(s, 0, 112))
        s.move(p(s, 180, 200))
        #expect(s.group == nil && s.geometry.center == parent && s.needNeutral && s.candidate == nil)
        s.move(p(s, 0, 260)); #expect(s.group == nil && s.needNeutral)
        s.move(p(s, 0, 52)); #expect(!s.needNeutral && s.candidate == nil)
        s.move(p(s, 0, 112)); #expect(s.group == "pointer")
    }
    @Test func parentCenterReturnRequiresOriginsAtLeast104Apart() {
        var s = session(); let parent = s.geometry.center
        s.move(p(s, 90, 112)); s.move(parent)
        #expect(s.group == nil && !s.needNeutral && s.candidate == nil)
        // Child clamps 10 pt, leaving 102 pt between its origin and parent.
        var near = session(at: CGPoint(x: 706, y: 600), bounds: CGRect(x: 0, y: 0, width: 1000, height: 1200))
        let original = near.geometry.center
        near.move(p(near, 90, 112))
        #expect(near.group == "draw" && !near.armed)
        near.move(near.geometry.center)
        #expect(RadialGeometry.distance(original, near.geometry.center) < 104)
        // Inside parent neutral, but outside the Back sector: no shortcut.
        near.move(CGPoint(x: original.x, y: original.y + 50))
        #expect(near.group == "draw")
    }
    @Test func rootAndChildEdgeClampArmingNeverWarpsTheCursor() {
        let b = CGRect(x: -1200, y: 24, width: 1200, height: 800)
        let cursor = CGPoint(x: -1198, y: 26)
        var s = session(at: cursor, bounds: b)
        #expect(b.contains(s.geometry.frame) && !s.armed)
        s.move(cursor); #expect(s.point == cursor && s.candidate == nil)
        s.move(p(s, 135)); #expect(s.candidate == nil)
        s.move(s.geometry.center); #expect(s.armed)
        s.move(p(s, 270, 112)) // Undo remains a root command.
        #expect(s.candidate?.id == "undo")
        var edge = session(at: CGPoint(x: 800, y: 600), bounds: CGRect(x: 0, y: 0, width: 1000, height: 1200))
        let entry = p(edge, 90, 112)
        edge.move(entry)
        #expect(edge.group == "draw" && !edge.armed && edge.point == entry)
        edge.move(p(edge, 90)); #expect(edge.candidate == nil)
        edge.move(edge.geometry.center); #expect(edge.armed)
        let g = RadialGeometry(cursor: CGPoint(x: 184, y: 400), bounds: bounds)
        #expect(!g.shifted) // exactly 8 pt is allowed
        #expect(RadialGeometry(cursor: CGPoint(x: 183.99, y: 400), bounds: bounds).shifted)
    }
    @Test func heldExtendsOnlyToOwnedDisplayPersistentIsBounded() {
        var held = session()
        held.move(p(held, 180, 500)); #expect(held.candidate?.id == "interact")
        held.move(CGPoint(x: 800, y: -1)); #expect(held.outside && held.candidate == nil)
        #expect(held.pendingCopy.title == "Return to this display")
        held.move(CGPoint(x: 800, y: 0)); #expect(held.candidate?.id == "interact")
        var persistent = session(.persistent)
        persistent.move(p(persistent, 135, 164)); #expect(persistent.candidate?.id == "clear")
        persistent.move(p(persistent, 135, 164.01)); #expect(persistent.candidate == nil)
        persistent.pointerDown(p(persistent, 135, 800)); #expect(persistent.pointerUp(p(persistent, 135, 800)) == nil && persistent.closed)
    }
    @Test func persistentHoverClickPairsAndDragAway() {
        var s = session(.persistent)
        let origin = s.geometry.center, click = p(s, 0, 112)
        s.move(click); #expect(s.group == nil)
        #expect(s.pointerUp(click) == nil && s.group == nil)
        s.pointerDown(click); #expect(s.pointerUp(click) == nil)
        #expect(s.group == "pointer" && s.parent?.center == origin && s.geometry.center == click && s.highlighted == nil)
        let choice = p(s, 0)
        s.pointerDown(choice); #expect(s.pointerUp(choice)?.id == "glove" && s.closed)
        var drag = session(.persistent); let clear = p(drag, 135)
        drag.pointerDown(clear); drag.move(p(drag, 225)); drag.move(clear)
        #expect(drag.pointerUp(clear) == nil && !drag.closed)
        drag.pointerDown(clear); #expect(drag.pointerUp(p(drag, 180)) == nil)
        drag.pointerDown(clear); drag.pointerCancelled(); #expect(drag.pointerUp(clear) == nil)
        drag.pointerDown(drag.geometry.center); #expect(drag.pointerUp(drag.geometry.center) == nil && drag.closed)
    }
    @Test func keyboardOrderDisabledInspectionAndRootNumbers() {
        var s = child("more")
        for index in [1, 2, 3, 4, 5, 6, 0, 1] {
            _ = s.key(.tab); #expect(s.highlighted == index && s.keyboard && s.ownsFocus)
        }
        #expect(s.inspected?.id == "redo" && s.candidate == nil && s.pendingCopy.subtitle == "Nothing to redo")
        #expect(s.key(.enter) == nil && !s.closed)
        _ = s.key(.left); #expect(s.highlighted == 0)
        _ = s.key(.tab, modifiers: .shift); #expect(s.highlighted == 6)
        _ = s.key(.number(3)); #expect(s.highlighted == 6)
        var root = session(.persistent)
        for number in 1...8 { _ = root.key(.number(number)); #expect(root.highlighted == number - 1) }
        _ = root.key(.number(8)); _ = root.key(.space)
        #expect(root.group == "more" && root.highlighted == nil)
        _ = root.key(.right); #expect(root.inspected?.id == "redo")
    }
    @Test func keyboardAndAXTransferOwnershipThroughPointerAndBack() {
        var s = session(); #expect(!s.ownsFocus)
        _ = s.key(.number(1)); #expect(s.ownsFocus)
        let expected = p(s, 0, 112)
        _ = s.key(.enter)
        #expect(s.group == "pointer" && s.geometry.center == expected && s.highlighted == nil && s.keyboard)
        s.move(s.geometry.center); #expect(s.ownsFocus && !s.keyboard)
        _ = s.key(.left); #expect(s.inspected?.isBack == true)
        _ = s.key(.space); #expect(s.group == nil && s.ownsFocus && s.keyboard && !s.needNeutral)
        var shifted = session(at: .zero)
        #expect(!shifted.armed)
        _ = shifted.activate(2)
        #expect(shifted.group == "draw" && shifted.armed && shifted.ownsFocus)
    }
    @Test(arguments: [RadialMode.held, .persistent])
    func escapeAndBackspaceSemantics(_ mode: RadialMode) {
        var s = child("draw", mode: mode)
        _ = s.key(.escape)
        #expect(mode == .held ? s.closed : (!s.closed && s.group == nil))
        if mode == .persistent { _ = s.key(.escape); #expect(s.closed) }
        var b = child("draw", mode: mode)
        _ = b.key(.backspace)
        #expect(!b.closed && (mode == .held ? b.group == "draw" : b.group == nil))
        if mode == .persistent { _ = b.key(.backspace); #expect(b.closed) }
    }
    @Test(arguments: [RadialKeyModifiers.command, .option, .control, [.control, .option]])
    func modifierChordsNeverNavigateOrActivate(_ modifiers: RadialKeyModifiers) {
        var s = session(.persistent)
        for key: RadialKey in [.right, .enter, .space, .number(4), .escape, .backspace] { #expect(s.key(key, modifiers: modifiers) == nil) }
        #expect(s.highlighted == nil && !s.closed && s.group == nil)
    }
    @Test func disabledAvailabilityRevalidatesEveryActivationAndHistoryKeepsSlots() {
        var s = session(.persistent)
        let ids = s.root.map(\.id)
        s.pointerDown(p(s, 135))
        s.updateHistory(canUndo: false, canRedo: false, hasInk: false)
        #expect(s.pointerUp(p(s, 135)) == nil && !s.closed)
        #expect(s.pendingCopy.subtitle == "Nothing to clear" && s.candidate == nil)
        #expect(s.activate(3) == nil)
        _ = s.key(.number(7)); #expect(s.pendingCopy.subtitle == "Nothing to undo" && s.key(.enter) == nil)
        #expect(s.release() == nil)
        var more = child("more")
        _ = more.key(.right); #expect(more.candidate == nil)
        more.updateHistory(canUndo: true, canRedo: true, hasInk: true)
        #expect(more.candidate?.id == "redo")
        more.updateHistory(canUndo: false, canRedo: false, hasInk: false)
        #expect(more.key(.enter) == nil)
        #expect(more.root.map(\.id) == ids)
        for (disabled, missing, expected) in [(Set(["glove"]), Set<String>(), "Disabled in Settings"), (Set<String>(), Set(["glove"]), "Pointer unavailable")] {
            var pointer = session(.persistent, disabled: disabled, missing: missing)
            _ = pointer.activate(0); pointer.move(p(pointer, 0))
            #expect(pointer.inspected?.id == "glove" && pointer.candidate == nil && pointer.pendingCopy.subtitle == expected)
            #expect(pointer.activate(pointer.highlighted!) == nil && pointer.release() == nil)
        }
    }
    @Test func currentFlagsAndPendingCopyUpdateWithoutReordering() {
        var s = session(.persistent); let ids = s.root.map(\.id)
        s.move(p(s, 180)); #expect(s.pendingCopy.title == "Cursor" && s.pendingCopy.subtitle == "Use apps normally")
        var state = current; state.interact = true; state.pointerID = "glove"; state.ink = .blue; state.tool = .eraser
        state.tapSound = true; state.muted = true; state.toolbar = false
        s.updateCurrent(state)
        #expect(s.pendingCopy.title == "Cursor" && s.root[4].selected && s.root.map(\.id) == ids)
        #expect(s.root[1].subtitle == "Ink: Blue")
        #expect(s.groups["pointer"]?.first { $0.id == "glove" }?.selected == true)
        #expect(s.groups["color"]?.first { $0.id == "blue" }?.selected == true)
        #expect(s.groups["draw"]?.first { $0.id == "eraser" }?.subtitle == "Starts drawing")
        #expect(s.groups["draw"]?.first { $0.id == "eraser" }?.accessibilityDetail == "Selects a drawing tool")
        #expect(s.groups["more"]?.first { $0.id == "sound" }?.pendingTitle == "Turn tap sound off")
        #expect(s.groups["more"]?.first { $0.id == "mute" }?.pendingTitle == "Unmute sounds")
        #expect(s.groups["more"]?.first { $0.id == "toolbar" }?.pendingTitle == "Show toolbar")
    }
    @Test func smallDisplayUsesListKeyboardAndPointerCancelIsTerminalForHeld() {
        var list = session(.persistent, bounds: CGRect(x: 0, y: 0, width: 320, height: 180))
        #expect(list.geometry.usesList)
        _ = list.key(.down); #expect(list.highlighted == 0)
        _ = list.key(.up); #expect(list.highlighted == 7)
        _ = list.key(.enter); #expect(list.group == "more")
        _ = list.key(.down); #expect(list.inspected?.isBack == true)
        var held = session(); held.move(p(held, 135)); held.pointerCancelled()
        #expect(held.release() == nil && held.closed)
    }
    @Test(arguments: ["root", "pointer", "color", "draw", "more"])
    func hysteresisAppliesOnlyAfterTargetExistsOnEveryRing(_ level: String) {
        let template = level == "root" ? session(.persistent) : child(level)
        let width = 360 / CGFloat(template.items.count)
        var s = template
        s.move(p(s, s.angle(for: 1)))
        s.move(p(s, s.angle(for: 1) + width / 2 + 3.99))
        #expect(s.highlighted == 1)
        s.move(p(s, s.angle(for: 1) + width / 2 + 4.01))
        #expect(s.highlighted == 2)
        s.move(s.geometry.center)
        s.move(p(s, s.angle(for: 1) + width / 2 + 0.01))
        #expect(s.highlighted == 2)
    }
    @Test func exactly104ParentReturnAndPersistentHubBack() {
        var held = session(at: CGPoint(x: 704, y: 600), bounds: CGRect(x: 0, y: 0, width: 1000, height: 1200))
        let parent = held.geometry.center
        held.move(p(held, 90, 112))
        #expect(held.armed && RadialGeometry.distance(parent, held.geometry.center) == 104)
        held.move(parent)
        #expect(held.group == nil && !held.needNeutral)
        var persistent = child("draw")
        persistent.pointerDown(persistent.geometry.center)
        #expect(persistent.pointerUp(persistent.geometry.center) == nil && persistent.group == nil && !persistent.closed)
    }
    @Test func missingFavoriteAndAvailabilityUpdatesKeepSlotAndRevalidate() {
        var slots = RadialFavorites.defaults; slots[0] = "custom-absent"
        var s = session(.persistent, favorites: slots)
        _ = s.activate(0); s.move(p(s, 0))
        #expect(s.inspected?.id == "custom-absent" && s.candidate == nil && s.pendingCopy.subtitle == "Pointer unavailable")
        let ids = s.items.map(\.id)
        s.updatePointers([])
        #expect(s.items.map(\.id) == ids)
        s.move(p(s, 45)); #expect(s.inspected?.id == "lavender" && s.candidate == nil)
        s.updatePointers([PointerCatalog.Entry(style: .lavender, enabled: true, available: true)])
        #expect(s.candidate?.id == "lavender")
        s.updatePointers([PointerCatalog.Entry(style: .lavender, enabled: false, available: true)])
        #expect(s.candidate == nil && s.activate(s.highlighted!) == nil)
        var browser = child("pointer")
        let all = browser.items.firstIndex { $0.id == "all" }!
        #expect(browser.activate(all)?.opensBrowser == true && browser.closed)
    }
    @Test func invalidLayoutAndNonfinitePointerCanNeverCommit() {
        var invalid = session(bounds: .zero)
        #expect(invalid.closed && invalid.release() == nil)
        var s = session()
        s.move(p(s, 135)); s.move(CGPoint(x: CGFloat.nan, y: 0))
        #expect(s.outside && s.candidate == nil && s.release() == nil)
    }
}
