import AppKit

enum PointerShadowStyle: String, CaseIterable, Codable {
    case original, contact
    var title: String { self == .original ? "Original" : "Contact" }
}

/// A short tap still reaches contact, then lifts away more gently on release.
struct ContactShadowResponse {
    private(set) var amount: CGFloat = 0
    private var lastUpdate: CFTimeInterval?
    private var contactUntil: CFTimeInterval = 0

    mutating func press(at time: CFTimeInterval) {
        lastUpdate = time
        contactUntil = time + 0.075
    }

    mutating func update(at time: CFTimeInterval, held: Bool) {
        let previous = lastUpdate ?? time
        let elapsed = max(0, time - previous)
        lastUpdate = time
        let contactDuration = held ? elapsed : min(elapsed, max(0, min(time, contactUntil) - previous))
        amount += (1 - amount) * CGFloat(1 - exp(-contactDuration / 0.020))
        amount *= CGFloat(exp(-(elapsed - contactDuration) / 0.065))
        let target: CGFloat = held || time < contactUntil ? 1 : 0
        if abs(target - amount) < 0.002 { amount = target }
    }
}

struct ContactShadowPose: Sendable {
    let asset: HandAsset
    let width: CGFloat
    let height: CGFloat
    let rodLength: CGFloat
    let rotation: CGFloat
    let press: CGFloat

    var tip: CGPoint {
        CGPoint(x: asset.tipX * width,
                y: rodLength + (asset.wrist - asset.tip) * height / (asset.wrist - asset.handTop))
    }

    /// Subpixel changes reuse the last texture; its contact anchor still follows
    /// the exact current fingertip every frame.
    var key: Key {
        Key(image: ObjectIdentifier(asset.image), dimensions: [
            Int((width * 2).rounded()), Int((height * 2).rounded()),
            Int((rodLength / 2).rounded()), Int((rotation * 100).rounded()),
            Int((press * 40).rounded())
        ])
    }
    struct Key: Equatable, Sendable {
        let image: ObjectIdentifier
        let dimensions: [Int]
    }
}

struct ContactShadowImage: Sendable {
    let image: CGImage
    let extent: CGRect
    let pose: ContactShadowPose
    let milliseconds: Double
}

/// Owns only the displayed texture and one pending render. Movement always
/// updates Core Animation immediately, even while a newer shadow is computing.
@MainActor final class ContactShadowLayer {
    let layer = CALayer()
    var didUpdate: (() -> Void)?
    private var desired: ContactShadowPose?
    private var rendered: ContactShadowImage?
    private var busy = false
    private var generation = 0
    private var failed = false
    private var renderCount = 0

    var isReady: Bool { rendered != nil && !layer.isHidden }
    var diagnostics: [String: Any] {
        ["ready": isReady, "pending": busy, "renders": renderCount,
         "renderMs": rendered?.milliseconds ?? 0]
    }

    func update(_ pose: ContactShadowPose) {
        desired = pose
        layer.isHidden = false
        positionTexture()
        startIfNeeded()
    }

    func disable() {
        if desired != nil { generation += 1 }
        desired = nil
        layer.isHidden = true
    }

    func reset() {
        disable()
        rendered = nil
        layer.contents = nil
        failed = false
    }

    private func positionTexture() {
        guard let desired, let rendered else { return }
        let extent = rendered.extent
        layer.bounds = CGRect(origin: .zero, size: extent.size)
        layer.anchorPoint = CGPoint(x: (rendered.pose.tip.x - extent.minX) / extent.width,
                                    y: (rendered.pose.tip.y - extent.minY) / extent.height)
        layer.position = desired.tip
        let scale = desired.height / rendered.pose.height
        layer.transform = CATransform3DMakeScale(scale, scale, 1)
    }

    private func startIfNeeded() {
        guard !busy, !failed, let desired,
              desired.key != rendered?.pose.key else { return }
        busy = true
        let ticket = generation
        Task { [weak self] in
            let result = await ContactShadowRenderer.shared.render(desired)
            guard let self else { return }
            self.busy = false
            // A result for a previous hand or a disabled setting cannot reappear.
            if ticket == self.generation, self.desired != nil {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                if let result {
                    self.rendered = result
                    self.renderCount += 1
                    self.layer.contents = result.image
                    self.positionTexture()
                } else {
                    self.failed = true
                }
                CATransaction.commit()
                self.didUpdate?()
            }
            self.startIfNeeded()
        }
    }
}

enum ShadowProjection {
    /// World-space light direction, transformed into the rotating hand's space.
    /// Every projected point on the contact line remains on that line.
    static func transform(direction: CGSize, rotation: CGFloat, tipY: CGFloat,
                          bias: CGSize = .zero) -> CGAffineTransform {
        let c = cos(rotation), s = sin(rotation)
        let x = direction.width * c + direction.height * s
        let y = -direction.width * s + direction.height * c
        let bx = bias.width * c + bias.height * s
        let by = -bias.width * s + bias.height * c
        return CGAffineTransform(a: 1, b: 0, c: -x, d: 1 - y,
                                 tx: x * tipY + bx, ty: y * tipY + by)
    }
}
