import AppKit

/// Owns system notifications separately from pointer input and rendering.
final class PresentationLifecycle {
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(workspace: NotificationCenter = NSWorkspace.shared.notificationCenter,
         distributed: NotificationCenter = DistributedNotificationCenter.default(),
         application: NotificationCenter = .default,
         stop: @escaping (String) -> Void, recover: @escaping () -> Void,
         accessibilityChanged: @escaping () -> Void = {}) {
        for name in ["com.apple.screenIsLocked", "com.apple.screensaver.didstart"] {
            observe(Notification.Name(name), in: distributed) { stop(name) }
        }
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observe(name, in: workspace) { stop(name.rawValue) }
        }
        observe(NSWorkspace.activeSpaceDidChangeNotification, in: workspace, recover)
        observe(NSApplication.didChangeScreenParametersNotification, in: application, recover)
        observe(NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, in: workspace, accessibilityChanged)
    }

    private func observe(_ name: Notification.Name, in center: NotificationCenter, _ action: @escaping () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in action() }
        observers.append((center, token))
    }
    deinit { for (center, token) in observers { center.removeObserver(token) } }
}

enum PresentationSession {
    /// A best-effort backstop for lock paths that omit distributed notifications.
    /// The public workspace/session notifications above remain the main mechanism.
    static var isLocked: Bool {
        (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}

enum MotionPacing {
    static func shouldSleep(stillFor: TimeInterval, settling: Bool, held: Bool, drawing: Bool) -> Bool {
        stillFor >= 3 && !settling && !held && !drawing
    }
}
