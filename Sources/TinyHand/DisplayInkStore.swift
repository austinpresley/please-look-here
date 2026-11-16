import AppKit

/// Stable display identity owns local-coordinate ink, independently of overlay geometry.
/// Disconnected displays remain retained for the life of this presentation session.
final class DisplayInkStore {
    struct Display: Equatable {
        let id: CGDirectDisplayID
        let frame: CGRect
        let scale: CGFloat

        init(id: CGDirectDisplayID, frame: CGRect, scale: CGFloat) {
            self.id = id; self.frame = frame; self.scale = scale
        }
        init?(_ screen: NSScreen) {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            self.init(id: number.uint32Value, frame: screen.frame, scale: screen.backingScaleFactor)
        }
    }

    let layer = CALayer()
    private let makeInk: () -> Ink
    private var documents: [CGDirectDisplayID: Ink] = [:]
    private(set) var display: Display?
    private(set) var ink: Ink
    var onChanged: (() -> Void)? {
        didSet {
            ink.onChanged = onChanged
            for document in documents.values { document.onChanged = onChanged }
        }
    }

    init(makeInk: @escaping () -> Ink = { Ink() }) {
        self.makeInk = makeInk
        ink = makeInk()
        layer.addSublayer(ink.layer)
        layer.isHidden = true
    }

    @discardableResult
    func select(_ target: Display) -> Bool {
        guard display != target else { return false }
        ink.cancel()
        if display?.id != target.id {
            ink.layer.removeFromSuperlayer()
            let selected = documents[target.id] ?? (display == nil ? ink : makeInk())
            documents[target.id] = selected
            ink = selected
            ink.onChanged = onChanged
            layer.addSublayer(ink.layer)
        }
        display = target
        ink.scale = target.scale
        return true
    }

    func activate() { layer.isHidden = false }
    func deactivate() { ink.cancel(); layer.isHidden = true }
}
