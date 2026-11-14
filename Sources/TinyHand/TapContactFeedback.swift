import Foundation

/// One cancellable contact sound per press. Moving into a drag lands it at once.
final class TapContactFeedback {
    private var work: DispatchWorkItem?
    private var action: (() -> Void)?
    private var generation = 0
    var pending: Bool { work != nil }
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) {
        cancel()
        if delay <= 0 { action(); return }
        self.action = action
        let token = generation
        let next = DispatchWorkItem { [weak self] in
            guard let self, self.generation == token else { return }
            let callback = self.action
            self.work = nil; self.action = nil
            callback?()
        }
        work = next
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: next)
    }
    func reachContact() {
        guard pending else { return }
        let callback = action
        cancel(); callback?()
    }
    func cancel() { generation += 1; work?.cancel(); work = nil; action = nil }
    deinit { work?.cancel() }
}
