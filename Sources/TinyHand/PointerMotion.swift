import Foundation

enum PointerMotion: String, CaseIterable {
    case original, responsive
    var title: String { self == .original ? "Original" : "Responsive" }
    /// Original TinyHand uses 0.08; AiHand uses adaptive 0.28/0.55/1 grip follow.
    func gripPosition(previous: CGFloat?, target: CGFloat) -> CGFloat {
        guard let previous = previous else { return target }
        let delta = abs(target - previous)
        let follow: CGFloat
        switch self {
        case .original: follow = 0.08
        case .responsive: follow = delta > 80 ? 1 : delta > 28 ? 0.55 : 0.28
        }
        return previous + (target - previous) * follow
    }
}

enum AppTheme: String, CaseIterable {
    case system, light, dark
    var title: String { rawValue.capitalized }
}
