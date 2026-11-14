import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

struct PointersPage: View {
    @ObservedObject var model: SettingsModel
    @State private var rowFrame: CGRect = .zero
    @State private var dragX: CGFloat = 0
    @State private var dragStart = 0
    @State private var floating: Floating?
    @State private var picking = false

    struct Floating {
        let style: PointerStyle
        let point: CGPoint
        let badge: String?
    }

    private var step: CGFloat {
        (rowFrame.width - 20 + 6) / CGFloat(Preferences.maxPinned)
    }

    private func overRow(_ p: CGPoint) -> Bool {
        rowFrame.insetBy(dx: -16, dy: -28).contains(p)
    }

    private func slot(at x: CGFloat, count: Int) -> Int {
        min(max(Int((x - rowFrame.minX - 10) / step), 0), max(0, count - 1))
    }

    private func rowDrag(_ value: DragGesture.Value) {
        let start = CGPoint(x: rowFrame.minX + value.startLocation.x, y: rowFrame.minY + value.startLocation.y)
        let p = CGPoint(x: rowFrame.minX + value.location.x, y: rowFrame.minY + value.location.y)
        if model.dragging == nil {
            let base = Preferences.pinnedStyles
            let i = Int((start.x - rowFrame.minX - 10) / step)
            guard start.x >= rowFrame.minX + 10, base.indices.contains(i) else {
                return
            }
            dragStart = i
            model.beginDrag(base[i])
        }
        guard let style = model.dragging else {
            return
        }
        var order = model.baseOrder.filter { $0 != style }
        if overRow(p) {
            dragX = value.translation.width
            order.insert(style, at: slot(at: p.x, count: order.count + 1))
            floating = nil
        } else if model.baseOrder.count > 1 {
            floating = Floating(style: style, point: p, badge: "minus.circle.fill")
        } else {
            order = model.baseOrder
            floating = Floating(style: style, point: p, badge: nil)
        }
        model.setDraft(order)
    }

    private func dropDrag() {
        let removing = floating?.badge == "minus.circle.fill"
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            dragX = 0
            if floating != nil && !removing {
                model.cancelDrag()
                model.pinMessage = "Keep at least one pointer in the toolbar."
            } else {
                model.endDrag()
            }
            floating = nil
        }
    }

    private func offset(_ style: PointerStyle) -> CGFloat {
        guard model.dragging == style, floating == nil, let i = model.pinnedOrder.firstIndex(of: style) else {
            return 0
        }
        return dragX - CGFloat(i - dragStart) * step
    }

    var body: some View {
        let pinned = model.pinnedOrder
        let full = Preferences.pinnedStyles.count >= Preferences.maxPinned
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("In your toolbar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    TextButton(title: "Reset") { model.resetToolbar() }
                }
                .padding(.horizontal, 4)
                HStack(spacing: 6) {
                    ForEach(pinned, id: \.self) { style in
                        let lifted = model.dragging == style
                        ToolbarSlot(style: style, model: model, lifted: lifted)
                            .offset(x: offset(style))
                            .zIndex(lifted ? 1 : 0)
                            .transaction { if lifted { $0.animation = nil } }
                    }
                    if !full {
                        AddSlot(open: $picking)
                            .popover(isPresented: $picking, arrowEdge: .bottom) {
                                PointerPicker(model: model) { picking = false }
                            }
                    }
                    ForEach(0..<max(0, Preferences.maxPinned - pinned.count - 1), id: \.self) { _ in
                        EmptySlot()
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                )
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear { rowFrame = g.frame(in: .named("pointersPage")) }
                        .onChange(of: g.frame(in: .named("pointersPage"))) { rowFrame = $0 }
                })
                .coordinateSpace(name: "toolbarRow")
                .gesture(
                    DragGesture(minimumDistance: 3, coordinateSpace: .named("toolbarRow"))
                        .onChanged { rowDrag($0) }
                        .onEnded { _ in dropDrag() }
                )
                Text(full
                     ? "The toolbar is full. Remove a pointer to add another. Drag to reorder."
                     : "Press + to add a pointer. Drag to reorder, or out to remove.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                if let message = model.pinMessage {
                    Text(message).font(.system(size: 12)).foregroundColor(.red).padding(.horizontal, 4)
                }
            }
            HandGestureSettings(model: model)
            PointerLibrary(model: model)
        }
        .coordinateSpace(name: "pointersPage")
        .overlay(alignment: .topLeading) {
            if let f = floating {
                FloatingPointer(style: f.style, badge: f.badge)
                    .position(f.point)
                    .allowsHitTesting(false)
            }
        }
    }
}


struct AddSlot: View {
    @Binding var open: Bool
    @State private var hovering = false

    var body: some View {
        Button {
            open.toggle()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(hovering || open ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(hovering || open ? 0.09 : 0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Add a pointer")
        .onHover { hovering = $0 }
    }
}


struct PointerPicker: View {
    @ObservedObject var model: SettingsModel
    let done: () -> Void
    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 72), spacing: 4)]

    var body: some View {
        let pinned = Set(Preferences.pinnedStyles)
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    section(nil, (PointerStyle.builtInHands + PointerStyle.presentationStyles).filter { PointerCatalog.selectableStyles.contains($0) }, pinned)
                    if !PointerStyle.customHands.isEmpty {
                        section("Your hands", PointerStyle.customHands.filter { PointerCatalog.selectableStyles.contains($0) }, pinned)
                    }
                }
                .padding(12)
            }
            .frame(height: 340)
            Divider()
            Button {
                done()
                model.startMakingHand()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars").font(.system(size: 11))
                    Text("Make your own hand…").font(.system(size: 12))
                    Spacer()
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
        .frame(width: 400)
    }

    private func section(_ title: String?, _ styles: [PointerStyle], _ pinned: Set<PointerStyle>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary).padding(.leading, 4)
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(styles, id: \.self) { style in
                    PickerCell(style: style, added: pinned.contains(style)) {
                        guard !pinned.contains(style) else {
                            return
                        }
                        model.pin(style)
                        done()
                    }
                }
            }
        }
    }
}


struct PickerCell: View {
    let style: PointerStyle
    let added: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let icon = pointerIcon(style) {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 42, height: 42)
                }
            }
            .frame(width: 62, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(hovering && !added ? 0.08 : 0))
            )
            .opacity(added ? 0.35 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(added ? "\(style.title) is already in the toolbar" : style.title)
        .onHover { hovering = $0 }
    }
}


struct YourHands: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your hands")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                TextButton(title: "Make your own…") { model.startMakingHand() }
            }
            .padding(.horizontal, 4)
            if PointerStyle.customHands.isEmpty {
                Text("Turn any idea into a hand with ChatGPT or another image tool.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            } else {
                HStack(spacing: 6) {
                    ForEach(PointerStyle.customHands, id: \.self) { style in
                        CustomHandChip(style: style, model: model)
                    }
                }
            }
            if let message = model.handMessage {
                Text(message).font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 4)
            }
        }
    }
}


struct CustomHandChip: View {
    let style: PointerStyle
    @ObservedObject var model: SettingsModel
    @State private var hovering = false
    @State private var swapping = false

    var body: some View {
        let pinned = Preferences.pinnedStyles.contains(style)
        let full = Preferences.pinnedStyles.count >= Preferences.maxPinned
        HStack(spacing: 6) {
            if let icon = pointerIcon(style) {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: 24, height: 24)
            }
            Text(style.title).font(.system(size: 12)).lineLimit(1)
            Button {
                model.removeHand(style)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.primary.opacity(hovering ? 0.12 : 0)))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .opacity(hovering ? 1 : 0)
            .help("Delete \(style.title)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.primary.opacity(hovering && !pinned ? 0.09 : 0.05)))
        .contentShape(Capsule())
        .onTapGesture {
            guard !pinned else {
                return
            }
            if full {
                swapping = true
            } else {
                model.pin(style)
            }
        }
        .onHover { hovering = $0 }
        .help(pinned ? "\(style.title) is in your toolbar" : "Click to add \(style.title) to the toolbar")
        .popover(isPresented: $swapping, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("The toolbar is full. Swap \(style.title) in for:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    ForEach(Preferences.pinnedStyles, id: \.self) { old in
                        SwapCell(style: old) {
                            model.swap(old, for: style)
                            swapping = false
                        }
                    }
                }
            }
            .padding(12)
        }
    }
}


struct SwapCell: View {
    let style: PointerStyle
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let icon = pointerIcon(style) {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 32, height: 32)
                }
            }
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(hovering ? 0.1 : 0.04)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Replace \(style.title)")
        .onHover { hovering = $0 }
    }
}

struct FloatingPointer: View {
    let style: PointerStyle
    let badge: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let icon = pointerIcon(style) {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 40, height: 40)
                }
            }
            .frame(width: 58, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
            )
            if let badge = badge {
                Image(systemName: badge)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white, badge == "nosign" ? Color.gray : Color.red)
                    .offset(x: 6, y: -6)
            }
        }
        .scaleEffect(1.06)
    }
}


struct ToolbarSlot: View {
    let style: PointerStyle
    @ObservedObject var model: SettingsModel
    let lifted: Bool
    @State private var hovering = false

    var body: some View {
        slot
    }

    private var slot: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let icon = pointerIcon(style) {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 40, height: 40)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                    .shadow(color: .black.opacity(lifted ? 0.22 : 0.08), radius: lifted ? 10 : 2, y: lifted ? 4 : 1)
            )
            .scaleEffect(lifted ? 1.06 : 1)
            if hovering && model.dragging == nil {
                Button {
                    model.unpin(style)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Remove from the toolbar")
                .offset(x: 5, y: -5)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .opacity(Preferences.disabledPointerIDs.contains(style.rawValue) ? 0.45 : 1)
        .help(Preferences.disabledPointerIDs.contains(style.rawValue) ? "\(style.title) is disabled. Its toolbar pin is kept." : style.title)
    }
}


struct EmptySlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.035))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
    }
}
