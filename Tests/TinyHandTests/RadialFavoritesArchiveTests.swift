import Foundation
import Testing
@testable import TinyHand

@Suite struct RadialFavoritesArchiveTests {
    @Test func favoriteStorageValidatesAndRetainsAbsentIDs() throws {
        let suite = "com.austinpresley.radial-favorites.\(UUID())"
        let storage = try #require(UserDefaults(suiteName: suite))
        defer { storage.removePersistentDomain(forName: suite) }
        #expect(RadialFavorites.load(from: storage) == RadialFavorites.defaults)
        var slots = RadialFavorites.defaults; slots[0] = "custom-absent"
        storage.set(slots, forKey: RadialFavorites.storageKey)
        #expect(RadialFavorites.load(from: storage) == slots)
        #expect(RadialFavorites.assigning("coral", to: 0, in: slots) == ["coral", "lavender", "custom-absent", "plush", "robot", "laser"])
        storage.set(["laser", "laser"], forKey: RadialFavorites.storageKey)
        #expect(RadialFavorites.load(from: storage) == RadialFavorites.defaults)
    }
    @Test(arguments: ["all", "back"])
    func reservedFavoriteIDsAreRejectedInStorageAssignmentAndArchive(id: String) throws {
        let fixture = try PresentationArchiveTests.Fixture(); defer { fixture.finish() }
        var slots = RadialFavorites.defaults; slots[0] = id
        #expect(!RadialFavorites.valid(slots))
        #expect(RadialFavorites.assigning(id, to: 0, in: RadialFavorites.defaults) == nil)
        fixture.defaults.set(slots, forKey: RadialFavorites.storageKey)
        #expect(RadialFavorites.load(from: fixture.defaults) == RadialFavorites.defaults)
        var archive = try fixture.archive()
        archive.setup.quickControlFavorites = slots
        #expect(throws: (any Error).self) { try archive.encoded() }
        archive.setup.quickControlFavorites = RadialFavorites.defaults
        let bytes = try archive.encoded()
        for preset in [false, true] {
            var json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            if preset {
                var presets = try #require(json["presets"] as? [[String: Any]])
                var setup = try #require(presets[0]["setup"] as? [String: Any])
                setup["quickControlFavorites"] = slots; presets[0]["setup"] = setup; json["presets"] = presets
            } else {
                var setup = try #require(json["setup"] as? [String: Any])
                setup["quickControlFavorites"] = slots; json["setup"] = setup
            }
            let invalid = try JSONSerialization.data(withJSONObject: json)
            #expect(throws: (any Error).self) { try PortablePresentationArchive.decode(invalid) }
        }
    }

    @Test func portableAndPresetRoundTripAndLegacyMigration() throws {
        let fixture = try PresentationArchiveTests.Fixture(); defer { fixture.finish() }
        var slots = RadialFavorites.defaults; slots[0] = "custom-missing"
        fixture.defaults.set(slots, forKey: RadialFavorites.storageKey)
        var archive = try fixture.archive()
        #expect(archive.setup.quickControlFavorites == slots)
        #expect(archive.presets[0].setup.quickControlFavorites == slots)
        let bytes = try archive.encoded()
        let decoded = try PortablePresentationArchive.decode(bytes)
        #expect(decoded == archive)
        #expect(decoded.setup.preferences[RadialFavorites.storageKey] as? [String] == slots)
        #expect(PresentationSetup.preferenceKeys.contains(RadialFavorites.storageKey))
        var json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        var setup = try #require(json["setup"] as? [String: Any]); setup.removeValue(forKey: "quickControlFavorites"); json["setup"] = setup
        var presets = try #require(json["presets"] as? [[String: Any]])
        for i in presets.indices { var old = presets[i]["setup"] as! [String: Any]; old.removeValue(forKey: "quickControlFavorites"); presets[i]["setup"] = old }
        json["presets"] = presets
        let legacy = try PortablePresentationArchive.decode(JSONSerialization.data(withJSONObject: json))
        #expect(legacy.setup.quickControlFavorites == RadialFavorites.defaults)
        #expect(legacy.presets[0].setup.quickControlFavorites == RadialFavorites.defaults)
        for invalid in [["laser"], Array(repeating: "laser", count: 6), ["../bad", "lavender", "coral", "plush", "robot", "laser"]] {
            archive.setup.quickControlFavorites = invalid
            #expect(throws: (any Error).self) { try archive.encoded() }
        }
        setup["quickControlFavorites"] = NSNull(); json["setup"] = setup
        #expect(throws: (any Error).self) { try PortablePresentationArchive.decode(JSONSerialization.data(withJSONObject: json)) }
        setup.removeValue(forKey: "quickControlFavorites"); setup["unknown"] = true; json["setup"] = setup
        #expect(throws: (any Error).self) { try PortablePresentationArchive.decode(JSONSerialization.data(withJSONObject: json)) }
    }
}
