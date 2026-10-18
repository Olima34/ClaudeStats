import SwiftUI

/// The Claude "spark": irregular rounded rays around a center.
struct ClaudeSpark: View {
    var size: CGFloat = 28
    var color: Color = Theme.brand
    var animate = false
    @State private var turn = 0.0

    private static let rays: [(angle: Double, length: Double)] = [
        (0, 1.0), (31, 0.82), (64, 0.95), (95, 0.78), (128, 1.0), (160, 0.86),
        (193, 0.97), (224, 0.8), (257, 0.93), (290, 0.84), (322, 0.98)
    ]

    var body: some View {
        Canvas { ctx, sz in
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let r = min(sz.width, sz.height) / 2
            let w = r * 0.2
            for ray in Self.rays {
                let a = (ray.angle - 90) * .pi / 180
                let inner = r * 0.12
                let outer = r * ray.length
                var p = Path()
                p.move(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
                p.addLine(to: CGPoint(x: c.x + cos(a) * (outer - w / 2), y: c.y + sin(a) * (outer - w / 2)))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(turn))
        .onAppear {
            guard animate else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { turn = 18 }
        }
    }
}

/// The little pixel creature of Claude Code.
struct PixelMascot: View {
    var pixel: CGFloat = 4
    var color: Color = Theme.brand
    var bob = true
    @State private var up = false
    @State private var blink = false

    // 1 = body, 2 = eye, 0 = empty
    private static let grid: [[Int]] = [
        [0, 1, 1, 1, 1, 1, 1, 1, 0],
        [0, 1, 2, 1, 1, 1, 2, 1, 0],
        [1, 1, 1, 1, 1, 1, 1, 1, 1],
        [0, 1, 1, 1, 1, 1, 1, 1, 0],
        [0, 1, 0, 1, 0, 1, 0, 1, 0]
    ]

    var body: some View {
        Canvas { ctx, _ in
            for (y, row) in Self.grid.enumerated() {
                for (x, v) in row.enumerated() where v != 0 {
                    let rect = CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: pixel, height: pixel)
                    if v == 2 {
                        ctx.fill(Path(rect), with: .color(blink ? color : Color.black.opacity(0.85)))
                    } else {
                        ctx.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: pixel * 9, height: pixel * 5)
        .offset(y: up ? -pixel * 0.6 : 0)
        .onAppear {
            guard bob else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { up = true }
            Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
                Task { @MainActor in
                    blink = true
                    try? await Task.sleep(nanoseconds: 140_000_000)
                    blink = false
                }
            }
        }
    }
}

/// Faint columns of random characters, like the Claude Code tab background.
struct MatrixBackdrop: View {
    var seed: UInt64 = 7
    var opacity: Double = 0.5

    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix(seed: seed)
            let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
            let colW: CGFloat = 8.2
            let rowH: CGFloat = 13
            let cols = Int(size.width / colW)
            let rows = Int(size.height / rowH)
            for c in 0..<cols {
                let colStrength = Double(rng.next() % 100) / 100
                guard colStrength > 0.35 else { continue }
                let startRow = Int(rng.next() % UInt64(max(1, rows)))
                let len = 4 + Int(rng.next() % 14)
                for r in startRow..<min(rows, startRow + len) {
                    let ch = chars[Int(rng.next() % UInt64(chars.count))]
                    let fade = 1 - Double(r - startRow) / Double(len)
                    let yFade = 1 - Double(r) / Double(max(rows, 1))
                    let text = Text(String(ch)).font(.mono(10.5)).foregroundColor(Theme.matrix)
                    ctx.opacity = opacity * fade * yFade * colStrength
                    ctx.draw(text, at: CGPoint(x: CGFloat(c) * colW + colW / 2, y: CGFloat(r) * rowH + rowH / 2))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
