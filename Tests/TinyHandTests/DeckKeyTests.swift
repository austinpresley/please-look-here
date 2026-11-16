import Foundation
import Testing
@testable import LookHerePleaseDeck

@Suite struct DeckKeyTests {
    private let on = Observed(active: true, interact: true, style: "robot", accessibility: true)
    private let off = Observed(active: false, interact: false, style: "lavender", accessibility: true)
    private let names = ["robot": "Robot", "lavender": "Lavender toy"]

    private func face(_ action: DeckAction, _ link: Link, settings: KeySettings = KeySettings(), transient: Transient? = nil) -> KeyFace {
        KeyModel.face(action: action, settings: settings, link: link, styleNames: names, transient: transient, pressed: false)
    }

    @Test func unavailableStatesAreDistinctFromOffAndSelection() {
        let faces = [face(.pointer, .connected(off)), face(.pointer, .stopped), face(.pointer, .unavailable), face(.pointer, .checking)]
        #expect(Set(faces.map(\.label)).count == faces.count)
        #expect(Set(faces.map { String(describing: $0.glyph) }).count == faces.count)
        for link in [Link.stopped, .unavailable, .checking] {
            for action in DeckAction.allCases {
                #expect(face(action, link, settings: KeySettings(style: "robot")).badge != .selected)
                #expect(face(action, link, settings: KeySettings(style: "robot")).tone != .active)
            }
        }
    }

    @Test func pendingKeepsTheLastObservationUntilAcknowledged() {
        let pending = face(.pointer, .connected(off), transient: .pending)
        #expect(pending.mark == .pending)
        #expect(pending.label == "Off")
        #expect(pending.tone == .idle)
    }

    @Test func persistentStateFollowsObservedValues() {
        #expect(face(.pointer, .connected(on)).badge == .selected)
        #expect(face(.interact, .connected(on)).label == "Interact On")
        #expect(face(.interact, .connected(off)).label == "Interact Off")
        let robot = KeySettings(style: "robot")
        #expect(face(.selectPointer, .connected(on), settings: robot).badge == .selected)
        #expect(face(.selectPointer, .connected(off), settings: robot).badge == nil)
        #expect(face(.selectPointer, .connected(on), settings: KeySettings(style: "gone")).label == "Missing")
        #expect(face(.selectPointer, .connected(on)).label == "Choose")
    }

    @Test func missingPermissionIsMarkedWithoutChangingInteract() {
        let denied = Observed(active: false, interact: true, style: "robot", accessibility: false)
        let shown = face(.interact, .connected(denied))
        #expect(shown.badge == .locked)
        #expect(shown.label == "Interact On")
    }

    @Test func interactNeverTargetsAStaleSample() {
        guard case .failure(let refusal) = KeyModel.request(action: .interact, settings: KeySettings(), link: .reconnecting(on)) else {
            Issue.record("A stale sample must not produce a target value")
            return
        }
        #expect(refusal.text == "No reply")
        guard case .success(let request) = KeyModel.request(action: .interact, settings: KeySettings(), link: .connected(on)) else {
            Issue.record("A fresh sample must produce a request")
            return
        }
        #expect(request["enabled"] as? Bool == false)
    }

    @Test func selectPointerRequestCarriesItsSettings() {
        guard case .success(let request) = KeyModel.request(action: .selectPointer, settings: KeySettings(style: "robot", activate: false), link: .stopped) else {
            Issue.record("Expected a request")
            return
        }
        #expect(request["operation"] as? String == "style")
        #expect(request["style"] as? String == "robot")
        #expect(request["activate"] as? Bool == false)
        #expect(KeySettings(["style": "robot"]).activate)
        #expect(KeySettings(["style": ""]).style == nil)
    }

    @Test func trackerRetainsASampleBrieflyThenReportsNoReply() {
        var tracker = LinkTracker()
        tracker.unreadable()
        #expect(tracker.link == .unavailable)
        tracker.observed(on)
        tracker.unreadable()
        tracker.unreadable()
        #expect(tracker.link == .reconnecting(on))
        tracker.unreadable()
        #expect(tracker.link == .unavailable)
        tracker.observed(on)
        tracker.appStopped()
        #expect(tracker.link == .stopped)
    }

    @Test func protocolCodesHaveShortKeyText() {
        #expect(KeyModel.rejectionText(code: "accessibility") == "Allow Drawing")
        #expect(KeyModel.rejectionText(code: "unknown-style") == "Missing")
        #expect(KeyModel.rejectionText(code: "disabled-style") == "Disabled")
        #expect(KeyModel.rejectionText(code: nil) == "Failed")
    }

    @Test func observedRejectsIncompleteState() {
        #expect(Observed(["active": true]) == nil)
        #expect(Observed(["active": true, "interact": false, "style": "robot", "accessibility": true]) != nil)
    }

    @Test func pointerToggleNeverSendsASampledOrSavedSelection() {
        for link in [Link.connected(on), .connected(off), .reconnecting(on), .stopped, .unavailable, .checking] {
            for settings in [KeySettings(), KeySettings(style: "gone", activate: false), KeySettings(["style": "robot", "activate": true])] {
                guard case .success(let request) = KeyModel.request(action: .pointer, settings: settings, link: link) else {
                    Issue.record("Pointer toggle must remain an app-owned operation")
                    continue
                }
                #expect(Set(request.keys) == ["version", "operation"])
                #expect(request["operation"] as? String == "toggle")
                #expect(request["version"] as? Int == 1)
            }
        }
    }

    @Test func pointerFaceUsesObservedHandAndLaserEvenWithStaleSavedSettings() {
        #expect(face(.pointer, .connected(on), settings: KeySettings(style: "lavender")).glyph == .style("robot"))
        #expect(face(.pointer, .connected(off)).glyph == .style("lavender"))
        let custom = Observed(active: false, interact: true, style: "custom-new", accessibility: true)
        #expect(face(.pointer, .connected(custom)).glyph == .style("custom-new"))
        let laser = Observed(active: true, interact: true, style: "laser", accessibility: true)
        #expect(face(.pointer, .connected(laser)).glyph == .laser)
        #expect(face(.pointer, .connected(laser)).label == "On")
        #expect(face(.pointer, .connected(off)).label == "Off")
    }

    @Test func toggleFeedbackKeepsObservationAndInputAcknowledgmentSeparate() {
        for transient in [Transient.pending, .accepted, .rejected("Disabled"), .uncertain] {
            let shown = KeyModel.face(action: .pointer, settings: KeySettings(style: "robot"), link: .reconnecting(off), styleNames: names, transient: transient, pressed: true)
            #expect(shown.glyph == .style("lavender"))
            #expect(shown.tone == .idle)
            #expect(shown.badge == .stale)
            #expect(shown.pressed)
            #expect(shown.mark != nil)
        }
        #expect(face(.pointer, .connected(off), transient: .accepted).label == "Off")
        #expect(face(.pointer, .connected(off), transient: .uncertain).label == "Check app")
        #expect(face(.pointer, .connected(off), transient: .rejected("Disabled")).label == "Disabled")
    }

    @Test func cycleRequestAndFaceIgnoreFixedSettingsAndSampledSelection() {
        for link in [Link.connected(on), .reconnecting(off), .unavailable, .stopped] {
            guard case .success(let request) = KeyModel.request(action: .choosePointer, settings: KeySettings(style: "gone", activate: true), link: link) else {
                Issue.record("Cycle must be app-owned"); continue
            }
            #expect(Set(request.keys) == ["version", "operation"])
            #expect(request["operation"] as? String == "cycle-pointer")
        }
        #expect(face(.choosePointer, .connected(on)).glyph == .style("robot"))
        #expect(face(.choosePointer, .connected(off)).label == "Off")
        for transient in [Transient.pending, .accepted, .uncertain, .rejected("Missing")] {
            let shown = KeyModel.face(action: .choosePointer, settings: KeySettings(style: "gone"), link: .reconnecting(off), styleNames: names, transient: transient, pressed: true)
            #expect(shown.glyph == .style("lavender"))
            #expect(shown.badge == .stale)
            #expect(shown.pressed && shown.mark != nil)
        }
    }

    @Test func pointerDirectionDefaultsForwardAndBackwardIntentIsCapturedAtPressTime() throws {
        #expect(DeckAction.choosePointer.rawValue == "com.austinpresley.lookhereplease.choose-pointer")
        #expect(DeckAction.selectPointer.rawValue == "com.austinpresley.lookhereplease.select-pointer")
        for payload in [[:], ["style": "old-hand", "activate": false], ["direction": "forward"]] as [[String: Any]] {
            let settings = KeySettings(payload)
            #expect(settings.pointerDirection == .forward)
            #expect(try KeyModel.selectionCommand(action: .choosePointer, settings: settings).get() == .cyclePointer)
        }
        var settings = KeySettings(["direction": "backward", "style": "old-hand", "activate": false])
        let backward = try KeyModel.selectionCommand(action: .choosePointer, settings: settings).get()
        #expect(backward == .cyclePointerBackward)
        #expect(Set(backward.request.keys) == ["version", "operation", "direction"])
        #expect(backward.request["direction"] as? String == "backward")
        #expect(backward.request["operation"] as? String == "cycle-pointer")
        var queue = CycleQueue()
        queue.enqueue(.init(context: "previous", keyID: UUID(), command: backward))
        settings = KeySettings(["direction": "forward"])
        queue.enqueue(.init(context: "next", keyID: UUID(), command: try KeyModel.selectionCommand(action: .choosePointer, settings: settings).get()))
        #expect(queue.takeNext()?.command == .cyclePointerBackward)
        queue.finish(uncertain: false)
        #expect(queue.takeNext()?.command == .cyclePointer)
        // Fixed pointer keys keep their saved destination and activation policy.
        let fixed = try KeyModel.request(action: .selectPointer, settings: KeySettings(["direction": "backward", "style": "robot", "activate": false]), link: .stopped).get()
        #expect(fixed["style"] as? String == "robot" && fixed["activate"] as? Bool == false)
        #expect(fixed["direction"] == nil)
    }

    @Test func malformedCycleDirectionsRequireAnExplicitInspectorChoice() {
        for value: Any in ["", "previous", "Forward", 1, true, NSNull(), ["backward"]] {
            let settings = KeySettings(["direction": value])
            #expect(settings.pointerDirection == nil)
            guard case .failure(let refusal) = KeyModel.selectionCommand(action: .choosePointer, settings: settings) else {
                Issue.record("Invalid direction must not silently become forward"); continue
            }
            #expect(refusal.text == "Choose Direction")
            #expect(face(.choosePointer, .connected(on), settings: settings).label == "Choose Direction")
        }
    }

    @Test func cycleQueueSerializesIntentAndNeverReplaysAnUncertainRequest() {
        var queue = CycleQueue()
        let a = CycleQueue.Intent(context: "a", keyID: UUID())
        let b = CycleQueue.Intent(context: "b", keyID: UUID())
        queue.enqueue(a); queue.enqueue(b); queue.enqueue(a)
        #expect(queue.takeNext() == a)
        #expect(queue.takeNext() == nil)
        queue.finish(uncertain: true)
        #expect(queue.takeNext() == nil)
        #expect(queue.waiting == [b, a])
        queue.statusConfirmed()
        #expect(queue.takeNext() == b)
        queue.finish(uncertain: false)
        #expect(queue.takeNext() == a)
        queue.finish(uncertain: false)
        #expect(queue.takeNext() == nil)
        queue.enqueue(a); queue.enqueue(b)
        queue.cancel(context: "a")
        #expect(queue.cancelAll() == [b])
        #expect(queue.takeNext() == nil)
    }

    @Test func toolChoicesAreStrictAndRequestsNeverUseObservedTool() throws {
        for choice in ToolChoice.allCases {
            let settings = KeySettings(["tool": choice.rawValue])
            for link in [Link.connected(on), .reconnecting(off), .stopped] {
                let request = try KeyModel.request(action: .chooseTool, settings: settings, link: link).get()
                #expect(request["operation"] as? String == (choice == .cycle ? "cycle-tool" : "tool"))
                #expect(request["tool"] as? String == (choice == .cycle ? nil : choice.rawValue))
                #expect(Set(request.keys) == (choice == .cycle ? ["version", "operation"] : ["version", "operation", "tool"]))
            }
        }
        #expect(KeySettings([:]).toolChoice == .cycle)
        for value: Any in ["", "bogus", "Pen", "cycle-pointer", 1, true, NSNull(), ["pen"], ["tool": "pen"]] {
            let settings = KeySettings(["tool": value])
            #expect(settings.toolChoice == nil)
            guard case .failure(let refusal) = KeyModel.request(action: .chooseTool, settings: settings, link: .connected(on)) else { Issue.record("Malformed tool must reject"); continue }
            #expect(refusal.text == "Choose Tool")
            #expect(face(.chooseTool, .connected(on), settings: settings).label == "Choose Tool")
        }
    }

    @Test func cycleToolFeedbackUsesActualToolAndIndependentReadiness() {
        for tool in ToolChoice.allCases where tool != .cycle {
            for active in [false, true] {
                for interact in [false, true] {
                    let observed = Observed(active: active, interact: interact, style: "robot", accessibility: true, tool: tool)
                    let shown = face(.chooseTool, .connected(observed), settings: KeySettings(["tool": "cycle"]))
                    #expect(shown.glyph == .tool(tool))
                    #expect(shown.label == tool.title)
                    #expect(shown.detail == "\(active ? "On" : "Off") · \(interact ? "Interact" : "Draw")")
                    #expect((shown.badge == .selected) == (active && !interact))
                }
            }
        }
        let denied = Observed(active: true, interact: false, style: "robot", accessibility: false, tool: .text)
        #expect(face(.chooseTool, .connected(denied)).badge == .locked)
        let busy = Observed(active: true, interact: false, style: "robot", accessibility: true, tool: .arrow, capturing: true)
        #expect(face(.chooseTool, .connected(busy)).badge == .busy)
        let pending = face(.chooseTool, .reconnecting(busy), transient: .pending)
        #expect(pending.glyph == .tool(.arrow) && pending.badge == .stale && pending.mark == .pending)
        let unknown = Observed(active: true, interact: false, style: "robot", accessibility: true, tool: nil)
        #expect(face(.chooseTool, .connected(unknown)).label == "Tool unknown")
        #expect(KeyModel.rejectionText(code: "capturing") == "Capturing")
    }

    @Test func fixedToolKeysKeepDistinctTargetsAgainstTheSameObservation() {
        for actual in ToolChoice.allCases where actual != .cycle {
            for active in [false, true] {
                for interact in [false, true] {
                    for accessibility in [false, true] {
                        for capturing in [false, true] {
                            let observed = Observed(active: active, interact: interact, style: "robot", accessibility: accessibility, tool: actual, capturing: capturing)
                            let faces = ToolChoice.allCases.filter { $0 != .cycle }.map { target in
                                face(.chooseTool, .connected(observed), settings: KeySettings(["tool": target.rawValue]))
                            }
                            #expect(Set(faces.map(\.label)).count == ToolChoice.allCases.count - 1)
                            for (target, shown) in zip(ToolChoice.allCases.filter { $0 != .cycle }, faces) {
                                let selected = target == actual && active && !interact && accessibility && !capturing
                                #expect(shown.glyph == .tool(target))
                                #expect(shown.label == target.title)
                                #expect(shown.detail == "\(active ? "On" : "Off") · \(interact ? "Interact" : "Draw")")
                                #expect((shown.badge == .selected) == selected)
                                #expect((shown.tone == .active) == selected)
                                if !accessibility { #expect(shown.badge == .locked) }
                                else if capturing { #expect(shown.badge == .busy) }
                            }
                        }
                    }
                }
            }
        }
    }

    @Test func fixedToolIdentitySurvivesPendingAndUnavailableFeedback() {
        let actual = Observed(active: true, interact: false, style: "robot", accessibility: true, tool: .pen)
        let rectangle = KeySettings(["tool": "rectangle"])
        for transient in [Transient.pending, .accepted, .uncertain, .rejected("Allow Drawing")] {
            let shown = face(.chooseTool, .connected(actual), settings: rectangle, transient: transient)
            #expect(shown.glyph == .tool(.rectangle))
            #expect(shown.label == "Rectangle")
            #expect(shown.badge != .selected && shown.tone == .idle)
            #expect(shown.mark != nil)
            #expect(shown.detail == (transient == .uncertain ? "Check app" : transient == .rejected("Allow Drawing") ? "Allow Drawing" : "On · Draw"))
        }
        for link in [Link.checking, .stopped, .unavailable, .reconnecting(actual), .reconnecting(Observed(active: true, interact: false, style: "robot", accessibility: true, tool: .rectangle))] {
            let shown = face(.chooseTool, link, settings: rectangle)
            #expect(shown.glyph == .tool(.rectangle) && shown.label == "Rectangle")
            #expect(shown.badge != .selected && shown.tone != .active)
        }
        let unknown = Observed(active: true, interact: false, style: "robot", accessibility: true, tool: nil)
        let shown = face(.chooseTool, .connected(unknown), settings: rectangle)
        #expect(shown.glyph == .tool(.rectangle) && shown.label == "Rectangle")
        #expect(shown.detail == "Tool unknown" && shown.badge == nil && shown.tone != .active)
    }

    @Test func mixedSelectionQueueCapturesMeaningAndCancelsByKey() throws {
        var queue = CycleQueue()
        let id = UUID()
        let pointer = CycleQueue.Intent(context: "pointer", keyID: UUID())
        let cycle = CycleQueue.Intent(context: "tool", keyID: id, command: .cycleTool)
        var settings = KeySettings(["tool": "arrow"])
        let fixed = CycleQueue.Intent(context: "tool", keyID: id, command: try KeyModel.selectionCommand(action: .chooseTool, settings: settings).get())
        queue.enqueue(pointer); queue.enqueue(cycle); queue.enqueue(fixed)
        settings = KeySettings(["tool": "number"])
        #expect(queue.takeNext() == pointer)
        queue.finish(uncertain: false)
        #expect(queue.takeNext() == cycle)
        queue.finish(uncertain: true)
        #expect(queue.takeNext() == nil)
        queue.statusConfirmed()
        #expect(queue.takeNext()?.command == .tool(.arrow))
        #expect(settings.toolChoice == .number)
        queue.finish(uncertain: false)
        queue.enqueue(cycle); queue.enqueue(pointer); queue.enqueue(fixed)
        queue.cancel(context: "tool")
        #expect(queue.waiting == [pointer])
    }
}
