import CoreGraphics
import Foundation
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct PointerLibraryFilterTests {
    private func addHand(_ name: String) throws -> PointerStyle {
        try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        try #require(ProcessInfo.processInfo.environment["TH_HANDS_DIR"] != nil)
        let context = try #require(CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.5, green: 0.25, blue: 0.75, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        return try CustomHands.add(try #require(context.makeImage()), ink: 0x8040BF, name: name)
    }

    @Test func everyFilterCombinationIntersectsAndPreservesLibraryOrder() throws {
        let custom = try addHand("Café pointer")
        let disabledCustom = try addHand("Other custom")
        defer {
            _ = try? CustomHands.remove(custom)
            _ = try? CustomHands.remove(disabledCustom)
        }
        let entries = [
            PointerCatalog.Entry(style: .lavender, enabled: true, available: true),
            PointerCatalog.Entry(style: .robot, enabled: false, available: true),
            PointerCatalog.Entry(style: custom, enabled: true, available: false),
            PointerCatalog.Entry(style: disabledCustom, enabled: false, available: true),
            PointerCatalog.Entry(style: .laser, enabled: true, available: true)
        ]
        let pins: Set<PointerStyle> = [.robot, custom]
        let expected: [[PointerStyle]] = [
            [.lavender, .robot, custom, disabledCustom, .laser],
            [.lavender, custom, .laser],
            [.robot, custom],
            [custom],
            [custom, disabledCustom],
            [custom],
            [custom],
            [custom]
        ]
        for mask in 0..<8 {
            var filter = PointerLibraryFilter()
            filter.enabledOnly = mask & 1 != 0
            filter.pinnedOnly = mask & 2 != 0
            filter.customOnly = mask & 4 != 0
            #expect(filter.entries(from: entries, pinned: pins).map(\.style) == expected[mask])
            filter.query = "  CAFE  "
            #expect(filter.entries(from: entries, pinned: pins).map(\.style) == [custom])
            filter.query = "robot"
            #expect(filter.entries(from: entries, pinned: pins).map(\.style) == (mask == 0 || mask == 2 ? [.robot] : []))
            filter.query = "other custom"
            #expect(filter.entries(from: entries, pinned: pins).map(\.style) == (mask == 0 || mask == 4 ? [disabledCustom] : []))
            filter.query = "no such pointer"
            #expect(filter.entries(from: entries, pinned: pins).isEmpty)
        }
        // Enabled and Pinned intentionally include unavailable artwork.
        let allFilters = PointerLibraryFilter(query: custom.rawValue, enabledOnly: true, pinnedOnly: true, customOnly: true)
        #expect(allFilters.entries(from: entries, pinned: pins).map(\.style) == [custom])
    }

    @Test func emptyResultsAndIndependentSearchAndFilterReset() {
        let entries = [PointerCatalog.Entry(style: .laser, enabled: true, available: true)]
        var filter = PointerLibraryFilter(query: "laser", enabledOnly: true, pinnedOnly: true, customOnly: false)
        #expect(filter.entries(from: entries, pinned: []).isEmpty)
        filter.query = ""
        #expect(filter.hasFilters && filter.isActive)
        #expect(filter.entries(from: entries, pinned: []).isEmpty)
        filter.enabledOnly = false
        filter.pinnedOnly = false
        #expect(!filter.hasFilters && !filter.isActive)
        #expect(filter.entries(from: entries, pinned: []).map(\.style) == [.laser])
        filter.query = "robot"
        #expect(filter.isActive && !filter.hasFilters)
        #expect(filter.entries(from: entries, pinned: []).isEmpty)
        filter = PointerLibraryFilter()
        #expect(filter.entries(from: entries, pinned: []).map(\.style) == [.laser])
        #expect(filter.entries(from: [], pinned: [.laser]).isEmpty)
        filter.query = " \n "
        #expect(filter.entries(from: entries, pinned: []).map(\.style) == [.laser])
    }

    @Test func filteringNeverWritesPreferencesOrRepairsHiddenSelection() throws {
        try #require(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"] != nil)
        Preferences.resetAll()
        defer { Preferences.resetAll() }
        Preferences.pinnedStyles = [.robot, .laser]
        Preferences.disabledPointerIDs = ["robot"]
        PointerStyle.saved = .laser
        let before = Preferences.storage.dictionaryRepresentation() as NSDictionary
        let entries = [
            PointerCatalog.Entry(style: .robot, enabled: false, available: true),
            PointerCatalog.Entry(style: .laser, enabled: true, available: true)
        ]
        let hidden = PointerLibraryFilter(query: "robot", enabledOnly: false, pinnedOnly: true)
        #expect(hidden.entries(from: entries, pinned: Set(Preferences.pinnedStyles)).map(\.style) == [.robot])
        let empty = PointerLibraryFilter(query: "nothing", enabledOnly: true, pinnedOnly: true, customOnly: true)
        #expect(empty.entries(from: entries, pinned: Set(Preferences.pinnedStyles)).isEmpty)
        #expect(PointerStyle.saved == .laser)
        #expect(Preferences.pinnedStyles == [.robot, .laser])
        #expect(Preferences.disabledPointerIDs == ["robot"])
        #expect(before.isEqual(to: Preferences.storage.dictionaryRepresentation()))
    }
}
