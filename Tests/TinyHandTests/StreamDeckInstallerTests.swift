import AppKit
import CryptoKit
import Testing
@testable import TinyHand

@Suite(.serialized) @MainActor struct StreamDeckInstallerTests {
    private func fixture() throws -> (URL, Bundle, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("s022-\(UUID().uuidString).app")
        let contents = root.appendingPathComponent("Contents")
        let resources = contents.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let info = ["CFBundleIdentifier": "com.austinpresley.s022.fixture", "CFBundleVersion": "42", "CFBundleShortVersionString": "1.0.2", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        let payload = Data("a verified installer fixture".utf8)
        let receipt = StreamDeckPackage(schema: 1, pluginID: StreamDeckPackage.pluginID, pluginVersion: "1.0.3.1", minimumHostVersion: "6.5", sha256: SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined(), appVersion: "1.0.2", appBuild: "42")
        try JSONEncoder().encode(receipt).write(to: resources.appendingPathComponent("StreamDeckInstaller.json"))
        try payload.write(to: resources.appendingPathComponent(StreamDeckPackage.filename))
        return (root, try #require(Bundle(url: root)), resources)
    }

    @Test func contractRejectsMissingCorruptAndMismatchedPackages() throws {
        let (root, _, resources) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let receipt = try StreamDeckPackage.read(resources: resources, appVersion: "1.0.2", appBuild: "42")
        #expect(try receipt.validate(resources: resources).lastPathComponent == StreamDeckPackage.filename)
        #expect(throws: StreamDeckPackage.Problem.corrupt) { try StreamDeckPackage.read(resources: resources, appVersion: "1.0.2", appBuild: "43") }
        try Data("damaged".utf8).write(to: resources.appendingPathComponent(StreamDeckPackage.filename))
        #expect(throws: StreamDeckPackage.Problem.corrupt) { try receipt.validate(resources: resources) }
        try FileManager.default.removeItem(at: resources.appendingPathComponent(StreamDeckPackage.filename))
        #expect(throws: StreamDeckPackage.Problem.missing) { try receipt.validate(resources: resources) }
        try Data("{}".utf8).write(to: resources.appendingPathComponent("StreamDeckInstaller.json"))
        #expect(throws: StreamDeckPackage.Problem.corrupt) { try StreamDeckPackage.read(resources: resources, appVersion: "1.0.2", appBuild: "42") }
        #expect(throws: StreamDeckPackage.Problem.missing) { try StreamDeckPackage.read(resources: nil, appVersion: "", appBuild: "") }
    }

    @Test func missingAndOldHostNeverOpenAnything() async throws {
        let (root, bundle, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        let absent = StreamDeckInstaller(bundle: bundle, findHost: { nil }, openPackage: { _, _ in calls += 1 })
        await absent.install()
        #expect(absent.needsHost && absent.message == "Install Stream Deck from Elgato, then try again.")
        let old = StreamDeckInstaller(bundle: bundle, findHost: { root }, hostVersion: { _ in "6.4" }, openPackage: { _, _ in calls += 1 })
        await old.install()
        #expect(old.needsHost && old.message == "Update Stream Deck to 6.5 or later, then try again.")
        #expect(calls == 0)
        #expect(!old.opening && !absent.opening)
    }

    @Test func openTargetsTheExactBundledPackageAndHostWithoutClaimingInstallation() async throws {
        let (root, bundle, resources) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let host = URL(fileURLWithPath: "/fixture/Stream Deck.app")
        var opened: [URL] = []
        let model = StreamDeckInstaller(bundle: bundle, findHost: { host }, hostVersion: { _ in "7.6.0" }, openPackage: { package, target in opened = [package, target] })
        model.refresh()
        #expect(model.version == "1.0.3.1")
        await model.install()
        #expect(opened.map(\.path) == [resources.appendingPathComponent(StreamDeckPackage.filename).path, host.path])
        #expect(model.message?.hasPrefix("Finish installation in Stream Deck.") == true)
        #expect(model.message?.localizedCaseInsensitiveContains("installed") == false)
        #expect(!model.opening)
    }

    @Test func corruptPackageAndFailedOpenAreActionableAndRetryable() async throws {
        let (root, bundle, resources) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        var opens = 0
        let model = StreamDeckInstaller(bundle: bundle, findHost: { root }, hostVersion: { _ in "7.6" }, openPackage: { _, _ in opens += 1; throw CocoaError(.fileReadUnknown) })
        await model.install()
        #expect(opens == 1 && model.message?.hasPrefix("Could not open the installer.") == true)
        await model.install()
        #expect(opens == 2)
        try Data("corrupt".utf8).write(to: resources.appendingPathComponent(StreamDeckPackage.filename))
        await model.install()
        #expect(opens == 2 && model.message == StreamDeckPackage.Problem.corrupt.message)
        try FileManager.default.removeItem(at: resources.appendingPathComponent(StreamDeckPackage.filename))
        await model.install()
        #expect(opens == 2 && model.message == StreamDeckPackage.Problem.missing.message)
    }

    @Test func aSecondClickCannotOpenASecondInstallerWhilePending() async throws {
        let (root, bundle, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        var continuation: CheckedContinuation<Void, Never>?
        var calls = 0
        let model = StreamDeckInstaller(bundle: bundle, findHost: { root }, hostVersion: { _ in "7.6" }, openPackage: { _, _ in
            calls += 1
            await withCheckedContinuation { continuation = $0 }
        })
        let first = Task { await model.install() }
        for _ in 0..<1000 { if continuation != nil { break }; await Task.yield() }
        #expect(model.opening)
        await model.install()
        #expect(calls == 1)
        continuation?.resume()
        await first.value
        #expect(!model.opening)
    }
}
