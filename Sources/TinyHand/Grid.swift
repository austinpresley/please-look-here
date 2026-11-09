import SwiftUI

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let section: CGFloat = 32
    static let margin: CGFloat = 20
}

final class GridProbes {
    static let shared = GridProbes()
    static var enabled: Bool { ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil }
    struct Probe: Codable {
        let kind: String
        let name: String
        let area: String
        let edge: String?
        let inset: Double
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }
    var probes: [String: Probe] = [:]
    var owners: [String: UUID] = [:]
    func write(to path: String, window: CGSize) {
        struct File: Codable { let window: [String: Double]; let probes: [Probe] }
        let value = File(window: ["width": window.width, "height": window.height], probes: Array(probes.values))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(value).write(to: URL(fileURLWithPath: path))
    }
}

private struct ProbeFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

private struct GridProbeModifier: ViewModifier {
    let kind: String
    let name: String
    let area: String
    let edge: String?
    let inset: CGFloat
    @State private var owner = UUID()
    func body(content: Content) -> some View {
        if GridProbes.enabled {
            content.background(GeometryReader { proxy in
                Color.clear.preference(key: ProbeFrameKey.self, value: ["\(kind):\(name)": proxy.frame(in: .global)])
            }).onPreferenceChange(ProbeFrameKey.self) { frames in
                guard let frame = frames["\(kind):\(name)"] else { return }
                GridProbes.shared.probes["\(kind):\(name)"] = .init(kind: kind, name: name, area: area, edge: edge, inset: inset,
                    x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
                GridProbes.shared.owners["\(kind):\(name)"] = owner
            }.onDisappear {
                let key = "\(kind):\(name)"
                if GridProbes.shared.owners[key] == owner { GridProbes.shared.probes[key] = nil; GridProbes.shared.owners[key] = nil }
            }
        } else { content }
    }
}

extension View {
    func gridArea(_ name: String, inset: CGFloat = Space.margin) -> some View {
        modifier(GridProbeModifier(kind: "area", name: name, area: name, edge: nil, inset: inset))
    }
    func gridProbe(_ name: String, area: String, edge: String? = "lead") -> some View {
        modifier(GridProbeModifier(kind: "probe", name: name, area: area, edge: edge, inset: 0))
    }
}
