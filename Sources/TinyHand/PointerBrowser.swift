import AppKit

enum PointerBrowserNameLayout {
    static let font = NSFont.systemFont(ofSize: 11)
    static let leading: CGFloat = 14
    // Measure the visible glyphs, not trailing side bearings. Gingerbread's ink
    // fits the 64-point cell even though its typographic advance is 65.13 points.
    static func inkBounds(_ text: String) -> CGRect {
        (text as NSString).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesDeviceMetrics, attributes: [.font: font])
    }
    private static func visible(_ text: String) -> String { text.replacingOccurrences(of: "\u{AD}", with: "") }
    private static func split(_ word: String, width: CGFloat) -> (head: String, tail: String) {
        // Explicit discretionary breaks take precedence over dictionary breaks.
        for index in word.indices.reversed() where word[index] == "\u{AD}" {
            let head = visible(String(word[..<index])), tail = String(word[word.index(after: index)...])
            if !head.isEmpty && !visible(tail).isEmpty && inkBounds(head + "-").width <= width { return (head, tail) }
        }
        let plain = visible(word), text = plain as NSString
        let locale = CFLocaleCreate(nil, CFLocaleIdentifier("en_US" as CFString))!
        var before = text.length
        while before > 0 {
            let index = CFStringGetHyphenationLocationBeforeIndex(plain as CFString, before, CFRange(location: 0, length: text.length), 0, locale, nil)
            if index == kCFNotFound { break }
            let head = text.substring(to: index)
            if inkBounds(head + "-").width <= width { return (head, text.substring(from: index)) }
            before = index
        }
        // Unknown words still break at composed characters, with a visible hyphen.
        var head = "", tail = plain
        for character in plain {
            let next = head + String(character)
            if inkBounds(next + "-").width > width { break }
            head = next; tail.removeFirst()
        }
        if head.isEmpty { head = String(tail.removeFirst()) }
        return (head, tail)
    }
    static func lines(_ title: String, width: CGFloat = 64) -> [String] {
        func fits(_ text: String) -> Bool { inkBounds(text).width <= width }
        var lines: [String] = [], line = ""
        for rawWord in title.split(whereSeparator: \.isWhitespace).map(String.init) {
            var word = rawWord
            if !line.isEmpty && fits(line + " " + visible(word)) { line += " " + visible(word); continue }
            if !line.isEmpty { lines.append(line); line = "" }
            while !fits(visible(word)) {
                let part = split(word, width: width)
                lines.append(part.head + "-"); word = part.tail
            }
            line = visible(word)
        }
        if !line.isEmpty { lines.append(line) }
        if lines.count > 2 {
            var last = lines[1]
            while !last.isEmpty && !fits(last + "…") { last.removeLast() }
            return [lines[0], last + "…"]
        }
        return lines
    }
}

/// Navigation and editing are independent of the live pointer and native focus.
struct PointerBrowserModel {
    enum Scope: Int { case all, quickControls }
    enum Focus: Equatable { case search, scope, edit, grid, editorDone, slot(Int) }
    var query = ""
    var scope: Scope = .all
    private(set) var editing = false
    private(set) var candidate: String?
    var inspected: String?
    var focus: Focus = .search
    static func handles(_ modifiers: RadialKeyModifiers) -> Bool { modifiers.intersection([.control, .option, .command]).isEmpty }
    static let destinations = ["North", "Northeast", "East", "Southeast", "Southwest", "West"]
    static func columns(availableWidth: CGFloat) -> Int { max(1, min(7, Int(floor((max(0, availableWidth) + 8) / 72)))) }
    func results(entries: [PointerCatalog.Entry], favorites: [String]) -> [PointerCatalog.Entry] {
        let source = scope == .all ? entries : favorites.compactMap { id in entries.first { $0.style.rawValue == id } }
        return source.filter { $0.selectable && (query.isEmpty || $0.style.title.localizedCaseInsensitiveContains(query)) }
    }
    mutating func reconcile(_ ids: [String]) {
        if !ids.contains(inspected ?? "") { inspected = ids.first }
        // A candidate can remain chosen while filtering, but never survive removal.
    }
    mutating func startEditing() { editing = true; candidate = nil }
    mutating func finishEditing() { editing = false; candidate = nil; focus = .edit }
    mutating func activate(_ id: String, valid: [String]) -> String? {
        guard valid.contains(id) else { return nil }
        inspected = id
        if editing { candidate = id; focus = .grid; return nil }
        return id
    }
    mutating func move(_ key: RadialKey, ids: [String], columns: Int) {
        guard !ids.isEmpty else { inspected = nil; return }
        if focus == .search && key == .down { inspected = ids.first; focus = .grid; return }
        guard focus == .grid else { return }
        let index = ids.firstIndex(of: inspected ?? "") ?? 0
        let columns = max(1, columns)
        var next = index
        switch key {
        case .left: if index % columns > 0 { next -= 1 }
        case .right: if index % columns < columns - 1 && index + 1 < ids.count { next += 1 }
        case .up: if index >= columns { next -= columns } else { focus = .search; return }
        case .down: if index + columns < ids.count { next += columns }
        default: return
        }
        inspected = ids[next]
    }
    mutating func assigned(to slot: Int) { focus = .slot(slot) }
    mutating func tab(backward: Bool, hasResults: Bool) {
        var order: [Focus] = [.search, .scope, .edit]
        if hasResults { order.append(.grid) }
        if editing { order.append(.editorDone) }
        if editing && candidate != nil { order += (0..<6).map(Focus.slot) }
        let i = order.firstIndex(of: focus) ?? 0
        focus = order[(i + (backward ? -1 : 1) + order.count) % order.count]
    }
    func assignmentName(candidateName: String, slot: Int, replacedName: String) -> String {
        "Use \(candidateName) in \(Self.destinations[slot]) Quick controls slot, replacing \(replacedName)"
    }
}

final class PointerBrowser: NSObject, NSWindowDelegate, NSSearchFieldDelegate {
    private final class Panel: NSPanel {
        var routeKey: ((NSEvent) -> Bool)?
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
        override func sendEvent(_ event: NSEvent) {
            if event.type == .keyDown, routeKey?(event) == true { return }
            super.sendEvent(event)
        }
    }
    private final class FlippedView: NSView {
        var onLayout: (() -> Void)?
        override var isFlipped: Bool { true }
        override func layout() { super.layout(); onLayout?() }
    }
    private final class Rule: NSView {
        override func draw(_ dirtyRect: NSRect) { NSColor.separatorColor.setFill(); NSBezierPath(rect: bounds).fill() }
    }
    private final class FocusButton: NSButton {
        override var acceptsFirstResponder: Bool { isEnabled }
        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            if window?.firstResponder === self {
                NSColor.keyboardFocusIndicatorColor.setStroke()
                let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6); ring.lineWidth = 2; ring.stroke()
            }
        }
    }
    private final class Cell: NSButton {
        var style: PointerStyle = .glove
        var current = false, candidate = false
        override var acceptsFirstResponder: Bool { true }
        override var isFlipped: Bool { false }
        override func draw(_ dirtyRect: NSRect) {
            let focused = window?.firstResponder === self
            if candidate || focused || isHighlighted {
                (candidate ? NSColor.controlAccentColor.withAlphaComponent(0.16) : NSColor.quaternaryLabelColor).setFill()
                NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8).fill()
            }
            if focused {
                NSColor.keyboardFocusIndicatorColor.setStroke()
                let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6); ring.lineWidth = 2; ring.stroke()
            }
            Toolbar.icon(for: style)?.draw(in: CGRect(x: 14, y: 32, width: 36, height: 36)) // grid: ok centered 36-point art in 64-point column
            let label = CGRect(x: 0, y: 2, width: bounds.width, height: 28)
            let lines = PointerBrowserNameLayout.lines(style.title, width: label.width)
            for (index, line) in lines.enumerated() {
                let ink = PointerBrowserNameLayout.inkBounds(line)
                // Draw each measured line directly, without a second text layout
                // introducing narrower line fragments or another word break.
                (line as NSString).draw(at: CGPoint(x: label.midX - ink.midX, y: label.maxY - CGFloat(index + 1) * PointerBrowserNameLayout.leading), withAttributes: [.font: PointerBrowserNameLayout.font, .foregroundColor: NSColor.labelColor])
            }
            if current {
                let badge = NSBezierPath(ovalIn: CGRect(x: 44, y: 32, width: 16, height: 16))
                NSColor.white.setFill(); badge.fill()
                NSColor.black.withAlphaComponent(0.3).setStroke(); badge.lineWidth = 1; badge.stroke()
                let tick = NSBezierPath(); tick.move(to: CGPoint(x: 48, y: 40)); tick.line(to: CGPoint(x: 51, y: 37)); tick.line(to: CGPoint(x: 57, y: 44))
                RadialAppearance.color(0x9E3A33).setStroke(); tick.lineWidth = 2; tick.lineCapStyle = .round; tick.lineJoinStyle = .round; tick.stroke()
            }
        }
        override func becomeFirstResponder() -> Bool { needsDisplay = true; return super.becomeFirstResponder() }
        override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }
    }
    let window: NSPanel
    private let root = FlippedView(), document = FlippedView(), scroll = NSScrollView()
    private let tools = FlippedView(), editor = FlippedView(), slotDocument = FlippedView(), slotScroll = NSScrollView()
    private let search = NSSearchField(), scope = NSSegmentedControl(labels: ["All", "Quick controls"], trackingMode: .selectOne, target: nil, action: nil)
    private let edit = FocusButton(title: "Edit Quick controls…", target: nil, action: nil)
    private let footer = NSTextField(labelWithString: ""), count = NSTextField(labelWithString: "")
    private let footerRule = Rule(), editorRule = Rule()
    private let editorTitle = NSTextField(labelWithString: "Quick controls favorites")
    private let editorDone = FocusButton(title: "Done", target: nil, action: nil)
    private let empty = NSTextField(labelWithString: "No matching pointers")
    private var cells: [Cell] = [], slotLabels: [NSTextField] = [], slotDirections: [NSTextField] = [], slotImages: [NSImageView] = [], slots: [NSButton] = []
    private(set) var model = PointerBrowserModel()
    private let focusDriver: QuickControlsFocus
    private var focusRestoration: QuickControlsFocusRestoration?
    var choose: ((String) -> Bool)?
    var current: () -> PointerStyle = { PointerStyle.saved }
    var onVisibilityChanged: (() -> Void)?
    private var visibleEntries: [PointerCatalog.Entry] = []
    private var columns = 1
    private var shortLayout: Bool { root.bounds.height < 480 }
    var visible: Bool { window.isVisible }
    var diagnostics: [String: Any] {
        ["visible": visible, "editing": model.editing, "searchText": search.stringValue, "scopeSegment": scope.selectedSegment, "candidate": model.candidate ?? "", "inspected": model.inspected ?? "", "focus": String(describing: model.focus), "columns": columns, "count": visibleEntries.count, "ids": visibleEntries.map { $0.style.rawValue }, "keyWindow": window.isKeyWindow, "window": window.windowNumber, "favorites": Preferences.quickControlFavorites, "currentPointer": current().rawValue, "focusedSlot": slots.firstIndex(where: { window.firstResponder === $0 }) ?? -1, "editFocused": window.firstResponder === edit,
         "contentSize": [root.bounds.width, root.bounds.height], "scrollViewport": [scroll.frame.minX, scroll.frame.minY, scroll.frame.width, scroll.frame.height],
         "scrollOffset": scroll.contentView.bounds.minY, "documentHeight": document.frame.height,
         "gridBottomInset": (shortLayout ? editor.frame.minY : document.frame.height) - (cells.map { $0.frame.maxY }.max() ?? 0),
         "shortLayout": shortLayout, "editorDocked": model.editing && editor.superview === root,
         "editorFrame": frameInRoot(editor), "editorHeaderFrame": frameInRoot(editorTitle), "editorDoneFrame": frameInRoot(editorDone),
         "editorHeaderVisible": model.editing && editorTitle.visibleRect.contains(editorTitle.bounds),
         "editorViewport": frameInRoot(shortLayout ? editor : slotScroll), "editorScrollOffset": slotScroll.contentView.bounds.minY,
         "footerFrame": frameInRoot(footer), "countHidden": count.isHidden, "editFrame": frameInRoot(edit), "searchFrame": frameInRoot(search), "scopeFrame": frameInRoot(scope),
         "candidateVisible": cells.first(where: { $0.style.rawValue == model.candidate }).map { $0.visibleRect.contains($0.bounds) } ?? false,
         "cells": cells.map { ["id": $0.style.rawValue, "frame": [$0.frame.minX, $0.frame.minY, $0.frame.width, $0.frame.height], "current": $0.current, "candidate": $0.candidate, "nameWidth": $0.bounds.width, "nameLines": PointerBrowserNameLayout.lines($0.style.title, width: $0.bounds.width)] as [String: Any] },
         "slots": slots.enumerated().map { ["slot": $0.offset, "frame": frameInRoot($0.element), "directionFrame": frameInRoot(slotDirections[$0.offset]), "artFrame": frameInRoot(slotImages[$0.offset]), "nameFrame": frameInRoot(slotLabels[$0.offset]), "name": slotLabels[$0.offset].stringValue, "label": $0.element.accessibilityLabel() ?? "", "hidden": $0.element.isHidden, "visible": $0.element.visibleRect.contains($0.element.bounds)] as [String: Any] }]
    }
    private func frameInRoot(_ view: NSView) -> [CGFloat] {
        let frame = view.convert(view.bounds, to: root)
        return [frame.minX, frame.minY, frame.width, frame.height]
    }
    init(focus: QuickControlsFocus = .system) {
        focusDriver = focus
        let panel = Panel(contentRect: CGRect(x: 0, y: 0, width: 560, height: 600), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        window = panel
        super.init()
        panel.title = "Pointers"; panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false
        panel.minSize = CGSize(width: 320, height: 180); panel.level = .floating; panel.delegate = self
        panel.contentView = root; panel.routeKey = { [weak self] in self?.key($0) ?? false }
        search.placeholderString = "Search pointers"; search.setAccessibilityLabel("Search pointers"); search.delegate = self
        scope.selectedSegment = 0; scope.target = self; scope.action = #selector(scopeChanged)
        scope.font = .systemFont(ofSize: 12, weight: .medium); scope.segmentStyle = .rounded
        scope.setAccessibilityLabel("Pointer scope")
        edit.target = self; edit.action = #selector(toggleEditing); edit.bezelStyle = .rounded; edit.focusRingType = .none
        edit.controlSize = .regular
        footer.font = .systemFont(ofSize: 13, weight: .semibold); footer.lineBreakMode = .byTruncatingTail
        count.font = .systemFont(ofSize: 12); count.textColor = .secondaryLabelColor
        editorTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        editorDone.target = self; editorDone.action = #selector(doneEditing); editorDone.bezelStyle = .rounded; editorDone.focusRingType = .none
        editorDone.setAccessibilityLabel("Done editing Quick controls favorites")
        empty.textColor = .secondaryLabelColor
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false; scroll.documentView = document
        slotScroll.hasVerticalScroller = true; slotScroll.autohidesScrollers = true; slotScroll.drawsBackground = false; slotScroll.documentView = slotDocument
        [search, scope].forEach { tools.addSubview($0) }
        [tools, edit, scroll, footerRule, footer, count, editor].forEach { root.addSubview($0) }
        [editorRule, editorTitle, editorDone, slotScroll].forEach { editor.addSubview($0) }
        document.addSubview(empty)
        for i in 0..<6 {
            let direction = NSTextField(labelWithString: ["N", "NE", "E", "SE", "SW", "W"][i]); direction.font = .systemFont(ofSize: 11); direction.textColor = .secondaryLabelColor
            direction.setAccessibilityElement(false)
            let image = NSImageView(); image.imageScaling = .scaleProportionallyUpOrDown; image.setAccessibilityElement(false)
            let label = NSTextField(wrappingLabelWithString: ""); label.font = .systemFont(ofSize: 13); label.maximumNumberOfLines = 0
            let button = FocusButton(title: "Use", target: self, action: #selector(assign(_:))); button.tag = i; button.bezelStyle = .rounded; button.focusRingType = .none
            slotDirections.append(direction); slotImages.append(image); slotLabels.append(label); slots.append(button)
            [direction, image, label, button].forEach { slotDocument.addSubview($0) }
        }
        root.onLayout = { [weak self] in self?.layout() }
    }
    func show(editing: Bool = false, size: CGSize? = nil, restoration: QuickControlsFocusRestoration? = nil) {
        if !visible {
            focusRestoration = restoration ?? focusDriver.save()
            model = PointerBrowserModel(); search.stringValue = ""; scope.selectedSegment = 0
            let bounds = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })?.visibleFrame ?? NSScreen.main!.visibleFrame
            window.setContentSize(size ?? CGSize(width: min(560, bounds.width), height: min(600, bounds.height - 28)))
            window.center()
        }
        if editing { model.startEditing() }
        reload(); scroll.contentView.scroll(to: .zero); scroll.reflectScrolledClipView(scroll.contentView)
        slotScroll.contentView.scroll(to: .zero); slotScroll.reflectScrolledClipView(slotScroll.contentView)
        _ = focusDriver.focus(window, nil, true)
        model.focus = .search; focus(); if editing { revealEditor() }; onVisibilityChanged?()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { close(); return false }
    func windowDidResize(_ notification: Notification) { layout() }
    func close() {
        window.orderOut(nil)
        let restoration = focusRestoration; focusRestoration = nil
        restoration?.restore()
        onVisibilityChanged?()
    }
    func refreshCurrent() { if visible { updateCopy() } }
    func controlTextDidChange(_ obj: Notification) { model.query = search.stringValue; reload(); scroll.contentView.scroll(to: .zero) }
    @objc private func scopeChanged() { model.scope = PointerBrowserModel.Scope(rawValue: scope.selectedSegment) ?? .all; reload(); scroll.contentView.scroll(to: .zero) }
    @objc private func toggleEditing() {
        if model.editing { finishEditing() } else { model.startEditing(); reload(); model.focus = .search; focus(); revealEditor() }
    }
    @objc private func doneEditing() { finishEditing() }
    func finishEditing() { model.finishEditing(); reload(); focus() }
    private func reload() {
        visibleEntries = model.results(entries: PointerCatalog.entries, favorites: Preferences.quickControlFavorites)
        model.reconcile(visibleEntries.map { $0.style.rawValue })
        cells.forEach { $0.removeFromSuperview() }
        cells = visibleEntries.map { entry in
            let cell = Cell(); cell.style = entry.style; cell.title = ""; cell.isBordered = false; cell.target = self; cell.action = #selector(picked(_:)); cell.setAccessibilityLabel(entry.style.title)
            cell.toolTip = entry.style.title; document.addSubview(cell); return cell
        }
        updateCopy(); layout()
        if model.focus == .grid || !shortLayout { revealCandidate() }
    }
    private func updateCopy() {
        let selected = model.inspected
        footer.stringValue = selected.flatMap { id in PointerCatalog.entries.first { $0.style.rawValue == id }?.style.title } ?? (model.editing ? "Choose a pointer, then use a slot below." : "No matching pointers")
        footer.toolTip = footer.stringValue
        count.stringValue = "\(visibleEntries.count) \(visibleEntries.count == 1 ? "pointer" : "pointers")"
        edit.title = model.editing ? "Done editing" : root.bounds.width < 440 ? "Edit favorites…" : "Edit Quick controls…"
        edit.setAccessibilityLabel(model.editing ? "Done editing" : "Edit Quick controls favorites")
        let favorites = Preferences.quickControlFavorites
        for i in 0..<6 {
            let replaced = PointerCatalog.entries.first { $0.style.rawValue == favorites[i] }?.style.title ?? favorites[i]
            slotLabels[i].stringValue = replaced; slotLabels[i].toolTip = replaced
            slotLabels[i].setAccessibilityLabel("\(PointerBrowserModel.destinations[i]) Quick controls favorite: \(replaced)")
            slotImages[i].image = PointerStyle(rawValue: favorites[i]).flatMap { Toolbar.icon(for: $0) }
            slots[i].title = model.candidate == favorites[i] ? "Here" : "Use"
            slots[i].isEnabled = model.candidate != nil
            let name = model.candidate.flatMap { id in PointerCatalog.entries.first { $0.style.rawValue == id }?.style.title } ?? "candidate pointer"
            slots[i].setAccessibilityLabel(model.assignmentName(candidateName: name, slot: i, replacedName: replaced))
            slots[i].toolTip = slots[i].accessibilityLabel()
            slots[i].isHidden = !model.editing; slotLabels[i].isHidden = !model.editing
        }
        for cell in cells {
            cell.current = cell.style == current(); cell.candidate = model.editing && cell.style.rawValue == model.candidate
            cell.setAccessibilityValue(cell.candidate ? "Edit candidate" : cell.current ? "Current pointer" : "")
            cell.needsDisplay = true
        }
        layoutFooter()
    }
    private func layoutFooter() {
        let width = root.bounds.width, height = root.bounds.height
        footerRule.frame = CGRect(x: 0, y: height - 44, width: width, height: 1)
        let editWidth = ceil((edit.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]).width) + 32
        edit.frame = CGRect(x: width - 16 - editWidth, y: height - 36, width: editWidth, height: 28)
        count.isHidden = width < 420
        let countWidth = count.isHidden ? 0 : ceil(count.fittingSize.width)
        let nameWidth = min(ceil(footer.fittingSize.width), max(0, edit.frame.minX - 32 - countWidth - (count.isHidden ? 0 : 8)))
        footer.frame = CGRect(x: 16, y: height - 32, width: nameWidth, height: 20)
        count.frame = CGRect(x: footer.frame.maxX + 8, y: height - 32, width: countWidth, height: 20)
    }
    private func layout() {
        let width = root.bounds.width, height = root.bounds.height
        let short = shortLayout
        updateCopy()
        let scopeWidth = max(164, ceil(scope.fittingSize.width))
        if short { scroll.frame = CGRect(x: 0, y: 0, width: width, height: max(16, height - 44)) }
        let toolsWidth = short ? scroll.contentSize.width : width
        let wrapped = toolsWidth - 32 - scopeWidth - 8 < 140
        let toolsHeight: CGFloat = wrapped ? 88 : 52
        let bodyHeight = max(16, height - 44 - (short ? 0 : toolsHeight))
        let editorHeight = model.editing && !short ? floor(bodyHeight * 0.45 / 4) * 4 : 0
        if tools.superview !== (short ? document : root) { tools.removeFromSuperview(); (short ? document : root).addSubview(tools) }
        if editor.superview !== (short ? document : root) { editor.removeFromSuperview(); (short ? document : root).addSubview(editor) }
        scroll.frame = CGRect(x: 0, y: short ? 0 : toolsHeight, width: width, height: bodyHeight - editorHeight)
        let documentWidth = scroll.contentSize.width
        tools.frame = CGRect(x: 0, y: 0, width: short ? documentWidth : width, height: toolsHeight)
        search.frame = CGRect(x: 16, y: 12, width: tools.frame.width - 32 - (wrapped ? 0 : scopeWidth + 8), height: 28)
        scope.frame = CGRect(x: wrapped ? 16 : search.frame.maxX + 8, y: wrapped ? 48 : 12, width: scopeWidth, height: 28)
        let available = max(64, documentWidth - 32)
        columns = PointerBrowserModel.columns(availableWidth: available)
        let rows = Int(ceil(Double(cells.count) / Double(columns)))
        let gridY = short ? toolsHeight : 0
        let gridHeight = max(40, CGFloat(rows) * 80 + 8)
        let gridX = floor((documentWidth - CGFloat(columns) * 72 + 8) / 2)
        for (i, cell) in cells.enumerated() { cell.frame = CGRect(x: gridX + CGFloat(i % columns) * 72, y: gridY + 4 + CGFloat(i / columns) * 80, width: 64, height: 72) }
        empty.isHidden = !cells.isEmpty; empty.frame = CGRect(x: 16, y: gridY + 8, width: available, height: 24)
        editor.isHidden = !model.editing
        let editorWidth = short ? documentWidth : width
        editor.frame = CGRect(x: 0, y: short ? gridY + gridHeight : height - 44 - editorHeight, width: editorWidth, height: editorHeight)
        editorRule.frame = CGRect(x: 0, y: 0, width: editorWidth, height: 1)
        editorTitle.frame = CGRect(x: 16, y: 12, width: max(0, editorWidth - 112), height: 20)
        editorDone.frame = CGRect(x: editorWidth - 80, y: 6, width: 64, height: 28)
        slotScroll.isHidden = short
        if short {
            if slotDocument.superview !== editor { slotScroll.documentView = nil; editor.addSubview(slotDocument) }
        } else {
            if slotScroll.documentView !== slotDocument { slotDocument.removeFromSuperview(); slotScroll.documentView = slotDocument }
            slotScroll.frame = CGRect(x: 0, y: 40, width: editorWidth, height: max(0, editorHeight - 40))
        }
        let slotWidth = short ? editorWidth : slotScroll.contentSize.width
        var rowY: CGFloat = 0
        for i in 0..<6 {
            let buttonX = slotWidth - 76, nameX: CGFloat = 86
            let nameWidth = max(0, buttonX - 8 - nameX)
            let measured = (slotLabels[i].stringValue as NSString).boundingRect(with: CGSize(width: max(1, nameWidth - 4), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: slotLabels[i].font!]).height
            let nameHeight = max(20, ceil(measured / 4) * 4)
            let rowHeight = max(36, nameHeight + 8)
            slotDirections[i].frame = CGRect(x: 16, y: rowY + (rowHeight - 20) / 2, width: 28, height: 20)
            slotImages[i].frame = CGRect(x: 52, y: rowY + (rowHeight - 26) / 2, width: 26, height: 26) // grid: ok prototype's 26-point slot artwork
            slotLabels[i].frame = CGRect(x: nameX, y: rowY + (rowHeight - nameHeight) / 2, width: nameWidth, height: nameHeight)
            slots[i].frame = CGRect(x: buttonX, y: rowY + (rowHeight - 28) / 2, width: 60, height: 28)
            rowY += rowHeight
        }
        slotDocument.frame = CGRect(x: 0, y: short ? 40 : 0, width: slotWidth, height: rowY + 8)
        if short { editor.setFrameSize(CGSize(width: editorWidth, height: 40 + rowY + 8)) }
        document.setFrameSize(CGSize(width: documentWidth, height: max(scroll.contentSize.height, gridY + gridHeight + (model.editing && short ? editor.frame.height : 0))))
    }
    private func revealEditor() {
        guard model.editing && shortLayout else { return }
        document.scrollToVisible(CGRect(x: 0, y: editor.frame.minY, width: 1, height: min(editor.frame.height, scroll.contentSize.height)))
    }
    private func revealCandidate() {
        guard model.editing, let cell = cells.first(where: { $0.style.rawValue == model.candidate }) else { return }
        cell.scrollToVisible(cell.bounds.insetBy(dx: 0, dy: -4))
    }
    @objc private func picked(_ sender: Cell) { activate(sender.style.rawValue) }
    private func activate(_ id: String) {
        if let chosen = model.activate(id, valid: visibleEntries.map { $0.style.rawValue }) {
            if choose?(chosen) == true { announce("Selected \(PointerStyle(rawValue: chosen)?.title ?? chosen)"); close() }
            else { announce("Pointer unavailable. Choose another pointer."); reload() }
        } else { updateCopy(); focus() }
    }
    @objc private func assign(_ sender: NSButton) {
        guard model.editing, let candidate = model.candidate,
              PointerCatalog.entries.contains(where: { $0.style.rawValue == candidate && $0.selectable }),
              Preferences.assignQuickControlFavorite(candidate, to: sender.tag) else { return }
        model.assigned(to: sender.tag); reload(); focus()
        announce("\(PointerStyle(rawValue: candidate)?.title ?? candidate) assigned to \(PointerBrowserModel.destinations[sender.tag])")
    }
    private func readFocus() {
        let responder = window.firstResponder
        if responder === edit { model.focus = .edit }
        else if responder === editorDone { model.focus = .editorDone }
        else if responder === scope { model.focus = .scope }
        else if let index = slots.firstIndex(where: { responder === $0 }) { model.focus = .slot(index) }
        else if let cell = responder as? Cell { model.focus = .grid; model.inspected = cell.style.rawValue }
        else { model.focus = .search }
    }
    private func focus() {
        let target: NSView?
        switch model.focus {
        case .search: target = search
        case .scope: target = scope
        case .edit: target = edit
        case .editorDone: target = editorDone
        case .slot(let i): target = slots[i]
        case .grid: target = cells.first { $0.style.rawValue == model.inspected }
        }
        if let target { window.makeFirstResponder(target); target.scrollToVisible(target.bounds.insetBy(dx: 0, dy: -4)) }
    }
    private func key(_ event: NSEvent) -> Bool {
        var modifiers: RadialKeyModifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        guard PointerBrowserModel.handles(modifiers), let key = RadialKey.keyCode(Int64(event.keyCode)) else { return false }
        readFocus()
        if key == .escape { if model.editing { finishEditing() } else { close() }; return true }
        if key == .tab { model.tab(backward: event.modifierFlags.contains(.shift), hasResults: !cells.isEmpty); focus(); return true }
        if key == .enter || key == .space && model.focus != .search {
            switch model.focus {
            case .slot(let i): assign(slots[i])
            case .edit: toggleEditing()
            case .editorDone: finishEditing()
            case .scope: return false
            default: if let id = model.inspected { activate(id) }
            }
            return true
        }
        if model.focus == .grid || model.focus == .search && key == .down {
            model.move(key, ids: visibleEntries.map { $0.style.rawValue }, columns: columns); updateCopy(); focus(); return true
        }
        return false
    }
    private func announce(_ message: String) { NSAccessibility.post(element: root, notification: .announcementRequested, userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue]) }

    /// Model-only verification, gated by the existing isolated test endpoint.
    func verifyAssignment(slot: Int) { if slots.indices.contains(slot) { assign(slots[slot]) } }
    func verify(query: String? = nil, scope: Int? = nil, candidate: String? = nil, finish: Bool = false) {
        if let query { search.stringValue = query; model.query = query }
        if let scope, let scope = PointerBrowserModel.Scope(rawValue: scope) { model.scope = scope; self.scope.selectedSegment = scope.rawValue }
        reload()
        if let candidate { activate(candidate) }
        if finish { finishEditing() }
    }
}
