import AppKit
import QuartzCore

/// AppKit delivers a coalesced callback on the main run loop for the view's display.
final class PointerDisplayLink: NSObject {
    private var driver: AnyObject?
    var onFrame: (() -> Void)?
    var isRunning: Bool { driver != nil }

    func start(on view: NSView) -> Bool {
        if driver != nil { return true }
        if #available(macOS 14, *) {
            let link = view.displayLink(target: self, selector: #selector(frame(_:)))
            link.add(to: .main, forMode: .common)
            driver = link
            return true
        }
        // macOS 13 keeps the adaptive timer with the same Responsive grip strategy.
        return false
    }

    func stop() {
        if #available(macOS 14, *), let link = driver as? CADisplayLink { link.invalidate() }
        driver = nil
    }
    @objc private func frame(_ sender: Any) { onFrame?() }
    deinit { stop() }
}
