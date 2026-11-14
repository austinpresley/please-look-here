import AppKit
import CryptoKit
import SwiftUI

/// The app signature seals both this receipt and the exact installer it describes.
struct StreamDeckPackage: Codable, Sendable {
    static let pluginID = "com.austinpresley.lookhereplease"
    static let filename = "com.austinpresley.lookhereplease.streamDeckPlugin"
    let schema: Int
    let pluginID: String
    let pluginVersion: String
    let minimumHostVersion: String
    let sha256: String
    let appVersion: String
    let appBuild: String

    enum Problem: Error, Equatable {
        case missing, corrupt
        var message: String {
            switch self {
            case .missing: return "The plugin installer is missing. Reinstall Look Here Please, then try again."
            case .corrupt: return "The plugin installer could not be verified. Reinstall Look Here Please, then try again."
            }
        }
    }

    static func read(resources: URL?, appVersion: String, appBuild: String) throws -> StreamDeckPackage {
        guard let resources,
              let data = try? Data(contentsOf: resources.appendingPathComponent("StreamDeckInstaller.json")) else { throw Problem.missing }
        guard let receipt = try? JSONDecoder().decode(Self.self, from: data),
              receipt.schema == 1, receipt.pluginID == Self.pluginID,
              receipt.appVersion == appVersion, receipt.appBuild == appBuild,
              receipt.sha256.count == 64, receipt.sha256.allSatisfy({ "0123456789abcdef".contains($0) }),
              validVersion(receipt.pluginVersion), validVersion(receipt.minimumHostVersion) else { throw Problem.corrupt }
        return receipt
    }

    static func validVersion(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return (2...4).contains(parts.count) && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) && UInt16($0) != nil }
    }

    func validate(resources: URL) throws -> URL {
        let url = resources.appendingPathComponent(Self.filename)
        guard FileManager.default.fileExists(atPath: url.path) else { throw Problem.missing }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), !data.isEmpty,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == sha256 else { throw Problem.corrupt }
        return url
    }
}

@MainActor final class StreamDeckInstaller: ObservableObject {
    static let downloadURL = URL(string: "https://www.elgato.com/us/en/s/downloads")!
    @Published private(set) var message: String?
    @Published private(set) var opening = false
    @Published private(set) var needsHost = false
    @Published private(set) var version: String?
    @Published private(set) var minimumHost = "6.5"

    private let resources: URL?
    private let appVersion: String
    private let appBuild: String
    private let findHost: () -> URL?
    private let hostVersion: (URL) -> String?
    private let openPackage: (URL, URL) async throws -> Void

    init(bundle: Bundle = .main,
         findHost: @escaping () -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.elgato.StreamDeck") },
         hostVersion: @escaping (URL) -> String? = { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String },
         openPackage: @escaping (URL, URL) async throws -> Void = StreamDeckInstaller.openInHost) {
        resources = bundle.resourceURL
        appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        appBuild = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        self.findHost = findHost
        self.hostVersion = hostVersion
        self.openPackage = openPackage
    }

    func refresh() {
        needsHost = findHost() == nil
        if let receipt = try? StreamDeckPackage.read(resources: resources, appVersion: appVersion, appBuild: appBuild) {
            version = receipt.pluginVersion
            minimumHost = receipt.minimumHostVersion
        }
    }

    func install() async {
        guard !opening else { return }
        opening = true
        message = "Opening Stream Deck…"
        defer { opening = false }
        do {
            let receipt = try StreamDeckPackage.read(resources: resources, appVersion: appVersion, appBuild: appBuild)
            version = receipt.pluginVersion
            minimumHost = receipt.minimumHostVersion
            guard let host = findHost() else {
                needsHost = true
                message = "Install Stream Deck from Elgato, then try again."
                return
            }
            needsHost = false
            guard let installedVersion = hostVersion(host), StreamDeckPackage.validVersion(installedVersion),
                  installedVersion.compare(receipt.minimumHostVersion, options: .numeric) != .orderedAscending else {
                needsHost = true
                message = "Update Stream Deck to \(receipt.minimumHostVersion) or later, then try again."
                return
            }
            guard let resources else { throw StreamDeckPackage.Problem.missing }
            let package = try await Task.detached { try receipt.validate(resources: resources) }.value
            try await openPackage(package, host)
            message = "Finish installation in Stream Deck. Confirm the plugin there. Your existing keys stay as they are."
        } catch let problem as StreamDeckPackage.Problem {
            message = problem.message
        } catch {
            message = "Could not open the installer. Open Stream Deck, then try Install Stream Deck Plugin again."
        }
    }

    private static func openInHost(_ package: URL, _ host: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([package], withApplicationAt: host, configuration: configuration) { app, error in
                if let error { continuation.resume(throwing: error) }
                else if app != nil { continuation.resume() }
                else { continuation.resume(throwing: CocoaError(.fileReadUnknown)) }
            }
        }
    }
}

struct StreamDeckSettings: View {
    @StateObject private var installer = StreamDeckInstaller()

    var body: some View {
        Card(title: "Stream Deck") {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(installer.version.map { "Bundled plugin \($0)" } ?? "Install the Look Here Please actions")
                    .font(.body)
                    .gridProbe("streamdeck.version", area: "streamdeck")
                Text("Requires Stream Deck \(installer.minimumHost) or later. Finish installation in Stream Deck, then add actions to your keys.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .gridProbe("streamdeck.requirements", area: "streamdeck")
                HStack(spacing: Space.sm) {
                    Button(installer.opening ? "Opening Stream Deck…" : "Install Stream Deck Plugin…") {
                        Task { await installer.install() }
                    }
                    .disabled(installer.opening)
                    .accessibilityIdentifier("install-stream-deck-plugin")
                    .help("Open this app's bundled plugin in Stream Deck for confirmation")
                    if installer.needsHost {
                        Link("Download Stream Deck…", destination: StreamDeckInstaller.downloadURL)
                    }
                }
                .gridProbe("streamdeck.actions", area: "streamdeck")
                if let message = installer.message {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("stream-deck-install-status")
                        .gridProbe("streamdeck.status", area: "streamdeck")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.lg)
            .gridArea("streamdeck", inset: Space.lg)
        }
        .onAppear { installer.refresh() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in installer.refresh() }
    }
}
