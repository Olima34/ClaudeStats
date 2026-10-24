import SwiftUI
import AppKit

// Liquid glass selection: one glass bubble per group of items (segments, sidebar rows, chips).
// It glides to the selected item on a bouncy spring and squashes like a drop. In a group set up
// with `liquidSelection`, it can also be grabbed and dragged: it lifts, follows the pointer,
// magnifies the titles beneath it like a lens, then snaps to the nearest item on release.

enum LiquidAxis { case horizontal, vertical }

/// The glass material of the bubble. `lifted`: while held, clearer and lighter.
struct LiquidGlass: View {
    var radius: CGFloat
    var lifted = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26, *) {
            shape.fill(scheme == .dark ? Theme.fill2 : Color.white.opacity(lifted ? 0.35 : 0.55))
                .glassEffect(lifted ? .clear : .regular, in: shape)
                .overlay(TopRim(radius: radius, color: .white.opacity(scheme == .dark ? 0.18 : 0.9)))
                .shadow(color: .black.opacity(scheme == .dark ? 0.28 : 0.10), radius: lifted ? 8 : 3, y: lifted ? 4 : 1.5)
        } else {
            shape.fill(scheme == .dark ? Theme.fill3 : Color.white)
                .overlay(TopRim(radius: radius))
                .shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.12), radius: lifted ? 6 : 1, y: lifted ? 3 : 1)
        }
    }
}

/// Stretches the bubble along its path, then lets it bounce back, each time `trigger` changes.
private struct Squash<T: Equatable>: ViewModifier {
    var trigger: T
    var axis: LiquidAxis
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Scale {
        var x: CGFloat = 1
        var y: CGFloat = 1
    }

    func body(content: Content) -> some View {
        let stretch: CGFloat = reduceMotion ? 0 : 0.16
        let along = 1 + stretch, across = 1 - stretch * 0.4
        content.keyframeAnimator(initialValue: Scale(), trigger: trigger) { view, s in
            view.scaleEffect(x: s.x, y: s.y)
        } keyframes: { _ in
            KeyframeTrack(\.x) {
                CubicKeyframe(axis == .horizontal ? along : across, duration: 0.12)
                SpringKeyframe(1, duration: 0.55, spring: .bouncy(duration: 0.45, extraBounce: 0.2))
            }
            KeyframeTrack(\.y) {
                CubicKeyframe(axis == .horizontal ? across : along, duration: 0.12)
                SpringKeyframe(1, duration: 0.55, spring: .bouncy(duration: 0.45, extraBounce: 0.2))
            }
        }
    }
}

private let settleSpring = Animation.spring(response: 0.42, dampingFraction: 0.66)

/// Runs `work` once the current update and the next one are done. A selection often swaps
/// a whole page (~100 ms of layout): starting the bubble's animation in that same frame would
/// freeze it mid-flight, so it starts right after, on an idle main thread.
@MainActor private func afterHeavyFrame(_ work: @escaping @MainActor () -> Void) {
    DispatchQueue.main.async { DispatchQueue.main.async { work() } }
}

/// Bubble for groups laid out freely (palette rows): items mark themselves with
/// `.matchedGeometryEffect(id:in:isSource: true)` and the bubble follows the selected one.
struct GlassBubble<ID: Hashable>: View {
    var selection: ID
    var namespace: Namespace.ID
    var radius: CGFloat
    var axis: LiquidAxis = .horizontal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LiquidGlass(radius: radius)
            .matchedGeometryEffect(id: selection, in: namespace, properties: .frame, isSource: false)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : settleSpring, value: selection)
            .modifier(Squash(trigger: selection, axis: axis))
            .allowsHitTesting(false)
    }
}

// MARK: - Draggable selection

private struct LiquidSpaceKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    fileprivate var liquidSpace: UUID? {
        get { self[LiquidSpaceKey.self] }
        set { self[LiquidSpaceKey.self] = newValue }
    }
}

private struct LiquidFramesKey: PreferenceKey {
    static let defaultValue: [AnyHashable: CGRect] = [:]
    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Reports an item's frame to the enclosing `liquidSelection`.
private struct LiquidItem: ViewModifier {
    var id: AnyHashable
    @Environment(\.liquidSpace) private var space

    func body(content: Content) -> some View {
        content.background {
            if let space {
                GeometryReader { g in
                    Color.clear.preference(key: LiquidFramesKey.self, value: [id: g.frame(in: .named(space))])
                }
            }
        }
    }
}

private enum Tracking { case ignored, pending, active }

private struct LiquidSelection<ID: Hashable>: ViewModifier {
    var selection: ID?
    var axis: LiquidAxis
    var radius: CGFloat
    var onSelect: (ID) -> Void

    @State private var space = UUID()
    @State private var frames: [AnyHashable: CGRect] = [:]
    /// The selection the bubble shows: it follows `selection` once the page has rendered.
    @State private var shown: ID?
    @State private var synced = false
    /// Pointer position along the axis while the bubble is held.
    @State private var drag: CGFloat?
    /// Pointer position across the axis, to center the lens under the cursor.
    @State private var cross: CGFloat = 0
    @State private var stretch: CGFloat = 0
    /// nil until the press is classified. A press on the selected item lifts the bubble at once;
    /// a press on another item only grabs it once the pointer moves (a click is left to the item).
    @State private var tracking: Tracking?
    @State private var under: AnyHashable?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far the bubble grows on each side when lifted, and how much the lens magnifies.
    private let lift: CGFloat = 4
    private let magnification: CGFloat = 1.2

    func body(content: Content) -> some View {
        content
            .environment(\.liquidSpace, space)
            .coordinateSpace(.named(space))
            .onPreferenceChange(LiquidFramesKey.self) { frames = $0 }
            .onAppear {
                shown = selection
                synced = true
            }
            .onChange(of: selection) { _, new in
                afterHeavyFrame {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : settleSpring) { shown = new }
                }
            }
            .transformPreference(LiquidFramesKey.self) { $0 = [:] }
            .background(alignment: .topLeading) { bubble }
            .overlay(alignment: .topLeading) { lens(content) }
            .simultaneousGesture(gesture)
    }

    // MARK: Geometry

    private func along(_ r: CGRect) -> CGFloat { axis == .horizontal ? r.midX : r.midY }
    private func along(_ p: CGPoint) -> CGFloat { axis == .horizontal ? p.x : p.y }

    private var ordered: [(id: AnyHashable, rect: CGRect)] {
        frames.map { (id: $0.key, rect: $0.value) }.sorted { along($0.rect) < along($1.rect) }
    }

    /// The bubble's rect for a pointer at `p`: it morphs between the two neighbouring items.
    private func rect(at p: CGFloat) -> CGRect? {
        let o = ordered
        guard let first = o.first, let last = o.last else { return nil }
        let c = min(max(p, along(first.rect)), along(last.rect))
        for i in 0..<max(0, o.count - 1) where c <= along(o[i + 1].rect) {
            let a = o[i].rect, b = o[i + 1].rect
            let t = (c - along(a)) / max(1, along(b) - along(a))
            func mix(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
            return CGRect(x: mix(a.minX, b.minX), y: mix(a.minY, b.minY),
                          width: mix(a.width, b.width), height: mix(a.height, b.height))
        }
        return last.rect
    }

    private func nearest(to p: CGFloat) -> AnyHashable? {
        ordered.min { abs(along($0.rect) - p) < abs(along($1.rect) - p) }?.id
    }

    private var shownRect: CGRect? {
        (synced ? shown : selection).flatMap { frames[AnyHashable($0)] }
    }

    private var currentRect: CGRect? {
        if let drag { return rect(at: drag) }
        return shownRect
    }

    // MARK: Pieces

    @ViewBuilder private var bubble: some View {
        if let r = currentRect {
            let held = drag != nil
            let grow = held && !reduceMotion ? lift : 0
            let a = 1 + stretch, c = 1 - stretch * 0.4
            LiquidGlass(radius: radius + grow, lifted: held)
                .frame(width: r.width + grow * 2, height: r.height + grow * 2)
                .scaleEffect(x: axis == .horizontal ? a : c, y: axis == .horizontal ? c : a)
                .modifier(Squash(trigger: shown, axis: axis))
                .offset(x: r.minX - grow, y: r.minY - grow)
                .allowsHitTesting(false)
        }
    }

    /// While held, the bubble becomes a lens: what lies beneath is blurred by the glass
    /// and the titles show through magnified.
    @ViewBuilder private func lens(_ content: Content) -> some View {
        if let d = drag, !reduceMotion, let r = rect(at: d) {
            GeometryReader { g in
                let lensRect = r.insetBy(dx: -lift, dy: -lift)
                let a = 1 + stretch, c = 1 - stretch * 0.4
                let shape = RoundedRectangle(cornerRadius: radius + lift, style: .continuous)
                ZStack(alignment: .topLeading) {
                    shape.fill(.regularMaterial)
                        .frame(width: lensRect.width, height: lensRect.height)
                        .offset(x: lensRect.minX, y: lensRect.minY)
                    content
                        .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
                        .scaleEffect(magnification, anchor: lensAnchor(lensRect, in: g.size))
                }
                .mask(alignment: .topLeading) {
                    shape
                        .frame(width: lensRect.width, height: lensRect.height)
                        .scaleEffect(x: axis == .horizontal ? a : c, y: axis == .horizontal ? c : a)
                        .offset(x: lensRect.minX, y: lensRect.minY)
                }
                .overlay(alignment: .topLeading) {
                    TopRim(radius: radius + lift, color: .white.opacity(0.22))
                        .frame(width: lensRect.width, height: lensRect.height)
                        .scaleEffect(x: axis == .horizontal ? a : c, y: axis == .horizontal ? c : a)
                        .offset(x: lensRect.minX, y: lensRect.minY)
                }
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    /// The lens magnifies around the cursor, kept inside the bubble.
    private func lensAnchor(_ r: CGRect, in size: CGSize) -> UnitPoint {
        let p = axis == .horizontal ? CGPoint(x: drag ?? r.midX, y: cross) : CGPoint(x: cross, y: drag ?? r.midY)
        let x = min(max(p.x, r.minX), r.maxX), y = min(max(p.y, r.minY), r.maxY)
        return UnitPoint(x: x / max(1, size.width), y: y / max(1, size.height))
    }

    // MARK: Gesture

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
            .onChanged { v in
                if tracking == nil {
                    let hit = { (r: CGRect) in r.insetBy(dx: -2, dy: -2).contains(v.startLocation) }
                    tracking = shownRect.map(hit) == true ? .active : (frames.values.contains(where: hit) ? .pending : .ignored)
                }
                if tracking == .pending, abs(axis == .horizontal ? v.translation.width : v.translation.height) > 4 {
                    tracking = .active
                }
                guard tracking == .active else { return }
                let p = along(v.location)
                let n = nearest(to: p)
                if n != under {
                    if under != nil { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
                    under = n
                }
                let speed = abs(axis == .horizontal ? v.velocity.width : v.velocity.height)
                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.78)) {
                    drag = p
                    cross = axis == .horizontal ? v.location.y : v.location.x
                    stretch = reduceMotion ? 0 : min(0.2, speed / 3000)
                }
            }
            .onEnded { v in
                defer { tracking = nil; under = nil }
                guard tracking == .active else { return }
                let moved = abs(axis == .horizontal ? v.translation.width : v.translation.height) > 3
                // A plain click is handled by the item's own button.
                if moved, let id = nearest(to: along(v.location))?.base as? ID { onSelect(id) }
                afterHeavyFrame {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : settleSpring) {
                        drag = nil
                        stretch = 0
                    }
                }
            }
    }
}

extension View {
    /// Marks an item of a `liquidSelection` group.
    func liquidItem<ID: Hashable>(_ id: ID) -> some View {
        modifier(LiquidItem(id: AnyHashable(id)))
    }

    /// Draws a draggable liquid glass bubble behind the `liquidItem`s of this view.
    func liquidSelection<ID: Hashable>(_ selection: ID?, axis: LiquidAxis, radius: CGFloat,
                                       onSelect: @escaping (ID) -> Void) -> some View {
        modifier(LiquidSelection(selection: selection, axis: axis, radius: radius, onSelect: onSelect))
    }
}
