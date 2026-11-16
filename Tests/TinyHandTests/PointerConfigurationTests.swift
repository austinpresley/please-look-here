import Foundation
import Testing
@testable import TinyHand

@Suite(.serialized) struct PointerConfigurationTests {
    private let baseline = EffectivePointerConfiguration(size: 0.13, shadow: true, shadowStyle: .original,
        soundEnabled: true, sound: .thock)

    private func fixture(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "com.austinpresley.pointer-defaults.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test func migrationPreservesEveryLegacySoundCombinationAndNeverWritesOnRead() throws {
        for hands in [true, false] {
            for laser in [true, false] {
                try fixture { storage in
                    storage.set(hands, forKey: "sound.hands")
                    storage.set(laser, forKey: "sound.laser")
                    let document = try PointerConfigurationDocument.load(from: storage)
                    let defaults = EffectivePointerConfiguration(size: 0.09, shadow: false, shadowStyle: .contact,
                        soundEnabled: hands, sound: .quack)
                    for id in ["lavender", "spotlight", "presentation", "custom-missing"] {
                        let value = document.effective(for: id, defaults: defaults)
                        #expect(value.size == 0.09 && value.sound == .quack)
                        #expect(value.soundEnabled == hands)
                    }
                    let laserValue = document.effective(for: "laser", defaults: defaults)
                    #expect(laserValue.soundEnabled == laser && laserValue.size == 0.09)
                    #expect(document.effective(for: "lavender", defaults: defaults).shadowStyle == .contact)
                    #expect(!document.effective(for: "presentation", defaults: defaults).shadow)
                    #expect(storage.object(forKey: PointerConfigurationDocument.storageKey) == nil)
                }
            }
        }
        fixture { storage in
            let migrated = PointerConfigurationDocument.migrated(from: storage)
            #expect(migrated.effective(for: "spotlight", defaults: baseline).soundEnabled)
            #expect(!migrated.effective(for: "laser", defaults: baseline).soundEnabled)
        }
    }

    @Test func soundChoiceNeverDetachesAppearanceOrEnablesSound() throws {
        var document = PointerConfigurationDocument()
        try document.patch(["sound": "coin"], for: "robot")
        let defaults = EffectivePointerConfiguration(size: 0.18, shadow: false, shadowStyle: .contact,
            soundEnabled: false, sound: .wood)
        let value = document.effective(for: "robot", defaults: defaults)
        #expect(value == EffectivePointerConfiguration(size: 0.18, shadow: false, shadowStyle: .contact,
            soundEnabled: false, sound: .coin))
        #expect(document.pointers["robot"]?.size == nil && document.pointers["robot"]?.shadow == nil)
    }

    @Test func eachFieldInheritsAndResetsIndependently() throws {
        let all: [String: Any] = ["size": 0.08, "shadow": false, "shadowStyle": "contact", "soundEnabled": false, "sound": "pew"]
        for field in PointerOverride.fields {
            var document = PointerConfigurationDocument()
            try document.patch(all, for: "robot")
            try document.patch([field: NSNull()], for: "robot")
            let value = document.effective(for: "robot", defaults: baseline)
            #expect(value.size == (field == "size" ? 0.13 : 0.08))
            #expect(value.shadow == (field == "shadow"))
            #expect(value.shadowStyle == (field == "shadowStyle" ? .original : .contact))
            #expect(value.soundEnabled == (field == "soundEnabled"))
            #expect(value.sound == (field == "sound" ? .thock : .pew))
        }
        var document = PointerConfigurationDocument()
        try document.patch(all, for: "robot")
        for field in PointerOverride.fields { try document.patch([field: NSNull()], for: "robot") }
        #expect(document.pointers["robot"] == nil)
        #expect(document.effective(for: "robot", defaults: baseline) == baseline)
    }

    @Test func archivesKeepUnavailableIDsAndSupportRecoveryWithoutCatalogMembership() throws {
        let id = "custom-absent"
        var document = PointerConfigurationDocument()
        let saved = PointerOverride(size: 0.07, shadow: false, shadowStyle: .contact, soundEnabled: true, sound: .squeak)
        try document.replace(saved, for: id)
        document = try PointerConfigurationDocument.decode(document.encoded())
        #expect(document.pointers[id] == saved)
        let deleted = document.pointers[id]
        try document.replace(nil, for: id)
        #expect(document.pointers[id] == nil)
        try document.replace(deleted, for: id)
        #expect(document.pointers[id] == saved)
        let storageData = try document.encoded()
        try fixture { storage in
            storage.set(storageData, forKey: PointerConfigurationDocument.storageKey)
            let loaded = try PointerConfigurationDocument.load(from: storage)
            #expect(loaded == document)
        }
    }

    @Test func importsAndAutomationPatchesRejectInvalidDataAtomically() throws {
        let invalid: [String] = [
            #"{"version":2,"pointers":{}}"#, #"{"version":true,"pointers":{}}"#,
            #"{"version":1,"pointers":{},"extra":1}"#, #"{"version":1,"pointers":{"../a":{}}}"#,
            #"{"version":1,"pointers":{"robot":{"size":true}}}"#,
            #"{"version":1,"pointers":{"robot":{"size":0.99}}}"#,
            #"{"version":1,"pointers":{"robot":{"soundEnabled":1}}}"#,
            #"{"version":1,"pointers":{"robot":{"shadow":0}}}"#,
            #"{"version":1,"pointers":{"robot":{"sound":"unknown"}}}"#,
            #"{"version":1,"pointers":{"robot":{"shadowStyle":"unknown"}}}"#,
            #"{"version":1,"pointers":{"robot":{"typo":false}}}"#,
            #"{"version":1,"pointers":{"spotlight":{"shadow":true}}}"#,
            #"{"version":1,"pointers":{"presentation":{"shadowStyle":"contact"}}}"#
        ]
        for json in invalid { #expect(throws: (any Error).self) { try PointerConfigurationDocument.decode(Data(json.utf8)) } }
        var document = PointerConfigurationDocument()
        try document.patch(["sound": "pop"], for: "robot")
        let before = document
        #expect(throws: (any Error).self) {
            _ = try document.applying(["robot": ["size": 0.10], "laser": ["shadow": true]])
        }
        #expect(document == before)
        let after = try document.applying(["robot": ["sound": NSNull(), "size": 0.10]])
        #expect(after.pointers["robot"] == PointerOverride(size: 0.10))
        #expect(try after.applying(["robot": NSNull()]).pointers["robot"] == nil)
    }

    @Test func typeSpecificApplicabilityAndLabelsMatchRendering() throws {
        #expect(PointerConfigurationPolicy("spotlight").sizeLabel == "Aperture size")
        #expect(PointerConfigurationPolicy("presentation").sizeLabel == "Rod thickness")
        let document = PointerConfigurationDocument()
        #expect(!document.effective(for: "spotlight", defaults: baseline).shadow)
        #expect(!document.effective(for: "laser", defaults: baseline).shadow)
        #expect(document.effective(for: "presentation", defaults: baseline).shadow)
        #expect(!PointerConfigurationPolicy("presentation").supportsShadowStyle)
    }

    @Test func unreadableArchiveIsPreservedForRecovery() throws {
        fixture { storage in
            let corrupt = Data("corrupt".utf8)
            storage.set(corrupt, forKey: PointerConfigurationDocument.storageKey)
            #expect(throws: (any Error).self) { try PointerConfigurationDocument.load(from: storage) }
            #expect(storage.data(forKey: PointerConfigurationDocument.storageKey) == corrupt)
        }
    }

    @Test func preferencesMigrationReadbackAndResetUseTheSameModel() throws {
        #expect(ProcessInfo.processInfo.environment["TINYHAND_DEFAULTS_SUITE"]?.contains("pointer-defaults") == true)
        Preferences.resetAll()
        defer { Preferences.resetAll() }
        Preferences.pointerSize = 0.11
        Preferences.showShadow = false
        Preferences.shadowStyle = .contact
        Preferences.tapSound = .boop
        Preferences.handSound = false
        #expect(Preferences.pointerConfiguration(for: "spotlight").sound == .boop)
        #expect(!Preferences.pointerConfiguration(for: "spotlight").soundEnabled)
        try Preferences.updatePointer("robot") { $0.sound = .pew }
        Preferences.pointerSize = 0.17
        #expect(Preferences.pointerConfiguration(for: "robot").size == 0.17)
        #expect(Preferences.pointerConfiguration(for: "robot").sound == .pew)
        #expect(!Preferences.pointerConfiguration(for: "robot").shadow)
        let state = Preferences.pointerConfigurationState(for: "robot")
        #expect(state["customized"] as? Bool == true)
        #expect((state["overrides"] as? [String: Any])?["size"] == nil)
        Preferences.laserSound = true
        #expect(Preferences.pointerConfiguration(for: "laser").soundEnabled)
        #expect(!Preferences.handSound)
        Preferences.resetAll()
        #expect(Preferences.storage.object(forKey: PointerConfigurationDocument.storageKey) == nil)
        #expect(Preferences.pointerConfiguration(for: "robot") == baseline)
        #expect(!Preferences.laserSound)
    }
}
