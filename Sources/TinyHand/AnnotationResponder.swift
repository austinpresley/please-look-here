import AppKit

/// Installed only in our controls' responder chains. Draw's existing scoped
/// shortcuts remain responsible for annotation undo while another app is frontmost.
final class AnnotationUndoResponder: NSResponder, NSMenuItemValidation {
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var canUndo: () -> Bool = { false }
    var canRedo: () -> Bool = { false }
    var focusRecovery: (() -> Bool)?
    var ignoredModifiers: NSEvent.ModifierFlags = []
    @objc func undo(_ sender: Any?) { if canUndo() { onUndo?() } }
    @objc func redo(_ sender: Any?) { if canRedo() { onRedo?() } }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(AnnotationUndoResponder.undo(_:)) { return canUndo() }
        if menuItem.action == #selector(AnnotationUndoResponder.redo(_:)) { return canRedo() }
        return true
    }
    func performKeyEquivalent(with event: NSEvent, firstResponder: NSResponder?) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .control, .option]).subtracting(ignoredModifiers)
        let key = event.charactersIgnoringModifiers?.lowercased()
        if flags == [.command, .shift], key == "u" { return focusRecovery?() ?? false }
        // Field editors own text undo. Do not redirect their Command-Z to Ink.
        guard !(firstResponder is NSTextView), !(firstResponder is NSTextField), key == "z", flags == .command || flags == [.command, .shift] else { return false }
        if flags.contains(.shift) { redo(nil) } else { undo(nil) }
        return true
    }
}

class AnnotationResponderPanel: NSPanel {
    let annotationUndo = AnnotationUndoResponder()
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        annotationUndo.nextResponder = nextResponder; nextResponder = annotationUndo
    }
    // NSWindow's standard undo action can stop responder-chain traversal before
    // nextResponder. Forward those selectors to the same scoped history route.
    @objc func undo(_ sender: Any?) { annotationUndo.undo(sender) }
    @objc func redo(_ sender: Any?) { annotationUndo.redo(sender) }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if annotationUndo.performKeyEquivalent(with: event, firstResponder: firstResponder) { return true }
        return super.performKeyEquivalent(with: event)
    }
}
