import AppKit

/// Native scrolling and 28-point rows; selection still belongs to RadialSession.
final class QuickControlsList: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let scroll = NSScrollView(), table = NSTableView()
    private let heading = NSTextField(labelWithString: ""), detail = NSTextField(labelWithString: "")
    private var session: RadialSession?
    private var tokens = RadialAppearance()
    private var level = ""
    var pointerStyle: PointerStyle = .glove
    var ink: InkChoice = .match
    var tool: DrawingTool = .pen
    var onScroll: ((CGFloat) -> Void)?
    private var scrollObserver: NSObjectProtocol?
    override var acceptsFirstResponder: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true
        layer?.cornerRadius = 12; layer?.masksToBounds = true
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        detail.font = .systemFont(ofSize: 11)
        addSubview(heading); addSubview(detail)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command")); table.addTableColumn(column)
        table.headerView = nil; table.rowHeight = RadialListLayout.rowHeight; table.intercellSpacing = .zero
        table.dataSource = self; table.delegate = self; table.selectionHighlightStyle = .none
        table.style = .plain; table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.backgroundColor = .clear; table.focusRingType = .none
        table.setAccessibilityHidden(true)
        scroll.documentView = table; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
        addSubview(scroll)
        scroll.contentView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak self] _ in
            guard let self else { return }; self.onScroll?(self.scroll.contentView.bounds.minY)
        }
        setAccessibilityRole(.menu); setAccessibilityLabel("Quick controls")
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) } }
    override func layout() {
        super.layout()
        heading.frame = CGRect(x: 12, y: bounds.height - 24, width: bounds.width - 24, height: 16)
        detail.frame = CGRect(x: 12, y: bounds.height - 40, width: bounds.width - 24, height: 14) // grid: ok 11/14 secondary copy
        scroll.frame = CGRect(x: 8, y: 8, width: bounds.width - 16, height: max(0, bounds.height - 52))
        table.tableColumns.first?.width = scroll.contentSize.width
        table.setFrameSize(CGSize(width: scroll.contentSize.width, height: table.frame.height))
        onScroll?(scroll.contentView.bounds.minY)
    }
    /// Convert AppKit's actual row rects after clip-view movement, including
    /// scrollRowToVisible, wheel scrolling and programmatic scrolls.
    var semanticGeometry: (frames: [CGRect], visible: [Bool]) {
        let viewport = scroll.contentView.convert(scroll.contentView.bounds, to: self)
        let rows = (0..<table.numberOfRows).map { table.convert(table.rect(ofRow: $0), to: self) }
        return (rows.map { $0.intersection(viewport).isNull ? .zero : $0.intersection(viewport) }, rows.map { $0.intersects(viewport) && !$0.intersection(viewport).isEmpty })
    }
    func update(_ session: RadialSession, tokens: RadialAppearance) {
        self.session = session; self.tokens = tokens
        layer?.backgroundColor = RadialAppearance.color(tokens.background).cgColor
        layer?.borderColor = RadialAppearance.color(tokens.text, alpha: tokens.contrast ? 1 : 0.2).cgColor; layer?.borderWidth = tokens.contrast ? 1 : 0.5
        heading.stringValue = session.title; heading.textColor = RadialAppearance.color(tokens.text)
        setAccessibilityHelp(Preferences.radialTrigger?.holdHelp ?? "Choose a held key in Shortcuts to open Quick controls.")
        detail.stringValue = session.inspected?.enabled == false ? session.inspected!.reason : (session.mode == .held ? "Release to choose" : "Esc goes back or closes")
        detail.textColor = RadialAppearance.color(tokens.secondary)
        let next = session.group ?? "root"
        if level != next { level = next; table.reloadData(); table.scroll(.zero) }
        for row in session.items.indices {
            if let cell = table.view(atColumn: 0, row: row, makeIfNecessary: false) as? Cell { configure(cell, at: row) }
        }
        if session.keyboard, let index = session.highlighted { table.scrollRowToVisible(index) }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { session?.items.count ?? 0 }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = (tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("row"), owner: self) as? Cell) ?? Cell()
        configure(cell, at: row); return cell
    }
    private func configure(_ cell: Cell, at index: Int) {
        guard let session, session.items.indices.contains(index) else { return }
        let item = session.items[index]
        let active = session.highlighted == index
        cell.textField?.stringValue = item.isBack ? "Back to Quick controls" : item.title
        cell.textField?.textColor = RadialAppearance.color(!item.enabled ? tokens.secondary : (active ? tokens.onSelection : tokens.text))
        let identity = RadialVisualIdentity.resolve(item, pointer: pointerStyle, ink: ink, tool: tool, list: true)
        cell.imageView?.image = identity.image(pointer: pointerStyle, tokens: tokens, side: 20)
        cell.imageView?.contentTintColor = identity.colorful ? nil : cell.textField?.textColor
        cell.state.stringValue = RadialVisualIdentity.rowState(item)
        cell.state.textColor = cell.textField?.textColor
        cell.layer?.backgroundColor = active && item.enabled ? RadialAppearance.color(tokens.selection).cgColor : NSColor.clear.cgColor
        cell.layer?.borderWidth = active && !item.enabled ? 1 : 0
        cell.layer?.borderColor = RadialAppearance.color(tokens.secondary).cgColor
        cell.focusHalo.isHidden = !active || !session.keyboard
        cell.focusRing.isHidden = cell.focusHalo.isHidden
        cell.focusHalo.strokeColor = RadialAppearance.color(tokens.dark ? tokens.background : 0xFFFFFF).cgColor
    }
    private final class Cell: NSTableCellView {
        let state = NSTextField(labelWithString: "")
        let focusHalo = CAShapeLayer(), focusRing = CAShapeLayer()
        init() {
            super.init(frame: .zero); identifier = NSUserInterfaceItemIdentifier("row"); wantsLayer = true; layer?.cornerRadius = 6
            let image = NSImageView(); image.imageScaling = .scaleProportionallyDown; imageView = image; addSubview(image)
            let text = NSTextField(labelWithString: ""); text.font = .systemFont(ofSize: 13, weight: .medium); textField = text; addSubview(text)
            state.font = .systemFont(ofSize: 13, weight: .medium); state.alignment = .center; addSubview(state)
            for outline in [focusHalo, focusRing] { outline.fillColor = nil; layer?.addSublayer(outline) }
            focusHalo.lineWidth = 4; focusRing.lineWidth = 2; focusRing.strokeColor = NSColor.systemBlue.cgColor
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layout() {
            super.layout()
            imageView?.frame = CGRect(x: 8, y: 4, width: 20, height: 20)
            textField?.frame = CGRect(x: 36, y: 6, width: max(0, bounds.width - 84), height: 16)
            state.frame = CGRect(x: bounds.width - 40, y: 6, width: 32, height: 16)
            let path = CGPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), cornerWidth: 4, cornerHeight: 4, transform: nil)
            focusHalo.path = path; focusRing.path = path
        }
    }
}
