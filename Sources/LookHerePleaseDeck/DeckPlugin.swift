import AppKit

/// All plugin state is confined to the main queue. App requests share one serial
/// queue, so an acknowledged command is never overwritten by an older status read.
final class DeckPlugin {
    private struct Key {
        let id = UUID()
        let action: DeckAction
        var settings: KeySettings
        var pressed = false
        var transient: Transient?
        var transientID = 0
        var shown: KeyFace?
    }

    private static let connectedPoll = 0.5
    private static let disconnectedPoll = 2.0
    private static let receiptDuration = 0.7
    private static let problemDuration = 2.0
    private static let stylesRefresh = 2.0
    private static let firstStylesRetry = 1.0
    private static let lastStylesRetry = 30.0

    private let registerEvent: String
    private let pluginUUID: String
    private let socket: URLSessionWebSocketTask
    private let worker = DispatchQueue(label: "com.austinpresley.lookhereplease.applink")
    private var keys: [String: Key] = [:]
    private var tracker = LinkTracker()
    private var cycles = CycleQueue()
    private var styleNames: [String: String] = [:]
    private var thumbnails: [String: CGImage] = [:]
    private var thumbnailData: [String: Data] = [:]
    private var styleOrder: [[String: String]] = []
    private var pollTimer: DispatchWorkItem?
    private var pollInFlight = false
    private var stylesLoading = false
    private var openInspectors: [String: String] = [:]
    private var stylesStale = false
    private var stylesRetryAt = Date.distantPast
    private var stylesRetryDelay = DeckPlugin.firstStylesRetry

    init(port: Int, pluginUUID: String, registerEvent: String) {
        self.pluginUUID = pluginUUID
        self.registerEvent = registerEvent
        socket = URLSession(configuration: .ephemeral).webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)")!)
    }

    func start() {
        socket.resume()
        send(["event": registerEvent, "uuid": pluginUUID])
        receive()
    }

    private func receive() {
        socket.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self, case .success(let message) = result else { exit(0) }
                var data: Data?
                switch message {
                case .string(let text): data = Data(text.utf8)
                case .data(let bytes): data = bytes
                @unknown default: break
                }
                if let data, let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { self.handle(event) }
                self.receive()
            }
        }
    }

    private func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message), let text = String(data: data, encoding: .utf8) else { return }
        socket.send(.string(text)) { _ in }
    }

    private func handle(_ event: [String: Any]) {
        guard let name = event["event"] as? String else { return }
        if name == "systemDidWakeUp" { return poll() }
        guard let context = event["context"] as? String else { return }
        let payload = event["payload"] as? [String: Any]
        switch name {
        case "willAppear":
            cycles.cancel(context: context)
            guard let raw = event["action"] as? String, let action = DeckAction(rawValue: raw) else { return }
            keys[context] = Key(action: action, settings: KeySettings(payload?["settings"] as? [String: Any]))
            render(context)
            poll()
            loadStylesIfNeeded()
        case "willDisappear":
            cycles.cancel(context: context)
            keys[context] = nil
        case "didReceiveSettings":
            keys[context]?.settings = KeySettings(payload?["settings"] as? [String: Any])
            keys[context]?.shown = nil
            render(context)
            loadStylesIfNeeded()
        case "keyDown": keyDown(context)
        case "keyUp":
            keys[context]?.pressed = false
            render(context)
        case "sendToPlugin":
            if let action = event["action"] as? String, payload?["request"] as? String == "styles" { requestStyles(action: action, context: context) }
        case "propertyInspectorDidDisappear":
            openInspectors[context] = nil
        default: break
        }
    }

    private func keyDown(_ context: String) {
        guard let key = keys[context] else { return }
        keys[context]?.pressed = true
        if key.action == .choosePointer || key.action == .chooseTool {
            // A release separates deliberate presses from duplicate/held keyDown.
            guard !key.pressed else { return render(context) }
            guard case .success(let command) = KeyModel.selectionCommand(action: key.action, settings: key.settings) else {
                return show(.rejected("Choose Tool"), on: context, for: Self.problemDuration)
            }
            cycles.enqueue(.init(context: context, keyID: key.id, command: command))
            show(.pending, on: context, for: nil)
            sendNextCycle()
            return
        }
        // Other actions retain their pending double-press suppression.
        if key.transient == .pending { return render(context) }
        switch KeyModel.request(action: key.action, settings: key.settings, link: tracker.link) {
        case .failure(let refusal):
            show(.rejected(refusal.text), on: context, for: Self.problemDuration)
        case .success(let request):
            show(.pending, on: context, for: nil)
            worker.async { [weak self] in
                let outcome = AppLink.send(request)
                DispatchQueue.main.async { self?.finish(outcome, context: context) }
            }
        }
    }

    private func sendNextCycle() {
        guard let intent = cycles.takeNext() else { return }
        guard keys[intent.context]?.id == intent.keyID else {
            cycles.finish(uncertain: false)
            return sendNextCycle()
        }
        show(.pending, on: intent.context, for: nil)
        worker.async { [weak self] in
            let outcome = AppLink.send(intent.command.request)
            DispatchQueue.main.async {
                guard let self else { return }
                let uncertain: Bool
                if case .uncertain = outcome { uncertain = true } else { uncertain = false }
                self.cycles.finish(uncertain: uncertain)
                if self.keys[intent.context]?.id == intent.keyID {
                    self.finish(outcome, context: intent.context)
                } else {
                    self.record(outcome)
                }
                if case .stopped = outcome { self.cancelWaitingCycles() }
                if !uncertain { self.sendNextCycle() }
                // Only poll's successful status response can resume an uncertain queue.
            }
        }
    }

    private func cancelWaitingCycles() {
        for intent in cycles.cancelAll() where keys[intent.context]?.id == intent.keyID {
            show(.rejected("Not running"), on: intent.context, for: Self.problemDuration)
        }
    }

    private func finish(_ outcome: AppLink.Outcome, context: String) {
        record(outcome)
        guard keys[context] != nil else { return }
        switch outcome {
        case .reply(let reply):
            if reply["ok"] as? Bool == true {
                show(.accepted, on: context, for: Self.receiptDuration)
            } else {
                let error = reply["error"] as? [String: Any]
                show(.rejected(KeyModel.rejectionText(code: error?["code"] as? String)), on: context, for: Self.problemDuration)
            }
        case .stopped: show(.rejected("Not running"), on: context, for: Self.problemDuration)
        case .uncertain: show(.uncertain, on: context, for: Self.problemDuration)
        }
    }

    private func show(_ transient: Transient, on context: String, for duration: TimeInterval?) {
        guard var key = keys[context] else { return }
        key.transient = transient
        key.transientID += 1
        let id = key.transientID
        let keyID = key.id
        keys[context] = key
        render(context)
        guard let duration else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.keys[context]?.id == keyID, self.keys[context]?.transientID == id else { return }
            self.keys[context]?.transient = nil
            self.render(context)
        }
    }

    /// One poll chain at most: an in-flight read or a single timer, never both.
    private func poll() {
        pollTimer?.cancel()
        pollTimer = nil
        guard !keys.isEmpty, !pollInFlight else { return }
        pollInFlight = true
        worker.async { [weak self] in
            let outcome = AppLink.send(["version": 1, "operation": "status"])
            DispatchQueue.main.async {
                guard let self else { return }
                self.pollInFlight = false
                self.record(outcome)
                if case .reply(let reply) = outcome, reply["ok"] as? Bool == true,
                   Observed(reply["state"] as? [String: Any]) != nil {
                    self.cycles.statusConfirmed()
                    self.sendNextCycle()
                } else if case .stopped = outcome {
                    self.cancelWaitingCycles()
                }
                self.schedulePoll()
            }
        }
    }

    private func schedulePoll() {
        guard !keys.isEmpty else { return }
        let timer = DispatchWorkItem { [weak self] in self?.poll() }
        pollTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + (tracker.link.isConnected ? Self.connectedPoll : Self.disconnectedPoll), execute: timer)
    }

    private func record(_ outcome: AppLink.Outcome) {
        let wasConnected = tracker.link.isConnected
        switch outcome {
        case .reply(let reply):
            if let observed = Observed(reply["state"] as? [String: Any]) { tracker.observed(observed) } else { tracker.unreadable() }
        case .stopped: tracker.appStopped()
        case .uncertain: tracker.unreadable()
        }
        if !wasConnected && tracker.link.isConnected { loadStylesIfNeeded(refresh: true) } else { loadStylesIfNeeded() }
        keys.keys.forEach(render)
    }

    private func loadStylesIfNeeded(refresh: Bool = false) {
        if refresh {
            stylesStale = true
            stylesRetryAt = .distantPast
        }
        // Toggle keys also show the app's current hand. Periodic safe reads pick up
        // new/replaced custom artwork and availability changes without reconnecting.
        let needed = keys.values.contains { $0.action == .pointer || $0.action == .choosePointer || $0.action == .selectPointer } || !openInspectors.isEmpty
        guard needed else { return }
        guard !stylesLoading, tracker.link.isConnected, Date() >= stylesRetryAt else { return }
        stylesLoading = true
        worker.async { [weak self] in
            let outcome = AppLink.send(["version": 1, "operation": "styles"])
            var names: [String: String]?, thumbnails: [String: CGImage] = [:], data: [String: Data] = [:], order: [[String: String]] = []
            if case .reply(let reply) = outcome, reply["ok"] as? Bool == true, let styles = reply["styles"] as? [[String: Any]], let directory = AppLink.directory {
                var loaded: [String: String] = [:]
                for style in styles {
                    guard let id = style["id"] as? String, let name = style["name"] as? String else { continue }
                    loaded[id] = name
                    order.append(["id": id, "name": name])
                    if let path = style["thumbnail"] as? String, path.hasPrefix(directory + "/"),
                       let bytes = try? Data(contentsOf: URL(fileURLWithPath: path)),
                       let source = CGImageSourceCreateWithData(bytes as CFData, nil),
                       let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                        thumbnails[id] = image
                        data[id] = bytes
                    }
                }
                names = loaded
            }
            DispatchQueue.main.async { [names, thumbnails, data, order] in
                guard let self else { return }
                self.stylesLoading = false
                if let names {
                    let artworkChanged = self.styleNames != names || self.thumbnailData != data
                    self.styleNames = names
                    self.thumbnails = thumbnails
                    self.thumbnailData = data
                    self.styleOrder = order
                    self.stylesStale = false
                    self.stylesRetryDelay = Self.firstStylesRetry
                    self.stylesRetryAt = Date().addingTimeInterval(Self.stylesRefresh)
                    if artworkChanged {
                        for context in self.keys.keys where self.keys[context]?.action == .pointer || self.keys[context]?.action == .choosePointer || self.keys[context]?.action == .selectPointer {
                            self.keys[context]?.shown = nil
                        }
                        self.keys.keys.forEach(self.render)
                    }
                } else {
                    // Status can recover without a reconnect, so retry this safe read on its own.
                    self.stylesStale = true
                    self.stylesRetryAt = Date().addingTimeInterval(self.stylesRetryDelay)
                    self.stylesRetryDelay = min(self.stylesRetryDelay * 2, Self.lastStylesRetry)
                }
                self.publishStyles()
            }
        }
    }

    private func requestStyles(action: String, context: String) {
        openInspectors[context] = action
        if tracker.link.isConnected {
            loadStylesIfNeeded(refresh: true)
        } else {
            publishStyles()
        }
    }

    /// Open inspectors stay subscribed, so a list that was empty fills in on recovery.
    private func publishStyles() {
        for (context, action) in openInspectors {
            send(["event": "sendToPropertyInspector", "action": action, "context": context,
                  "payload": ["styles": styleOrder, "available": tracker.link.isConnected && !stylesStale]])
        }
    }

    private func render(_ context: String) {
        guard let key = keys[context] else { return }
        let face = KeyModel.face(action: key.action, settings: key.settings, link: tracker.link, styleNames: styleNames, transient: key.transient, pressed: key.pressed)
        guard face != key.shown else { return }
        keys[context]?.shown = face
        var thumbnail: CGImage?
        if case .style(let id) = face.glyph { thumbnail = thumbnails[id] }
        guard let png = KeyArt.png(face, image: thumbnail) else { return }
        send(["event": "setImage", "context": context, "payload": ["image": "data:image/png;base64," + png.base64EncodedString(), "target": 0]])
    }
}
