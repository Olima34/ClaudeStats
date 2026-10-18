// Renders the ClaudeStats app icon (1024×1024 PNG).
// Usage: swift scripts/make_icon.swift <output.png>
import AppKit
import CoreGraphics

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// Squircle background (macOS icon grid: 824 pt box, ~185 pt corner radius).
let box = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: box, cornerWidth: 186, cornerHeight: 186, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgb(0x000000, 0.35))
ctx.addPath(shape)
ctx.setFillColor(rgb(0x141413))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape)
ctx.clip()
let bg = CGGradient(colorsSpace: cs, colors: [rgb(0x232322), rgb(0x0E0E0D)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 200, y: 924), end: CGPoint(x: 824, y: 100), options: [])
// Warm glow behind the spark.
let glow = CGGradient(colorsSpace: cs, colors: [rgb(0xD97757, 0.34), rgb(0xD97757, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 590), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 590), endRadius: 380, options: [])

// Faint "matrix" characters.
let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
var seed: UInt64 = 12345
func rnd() -> UInt64 { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return seed >> 33 }
let font = NSFont.monospacedSystemFont(ofSize: 26, weight: .regular)
let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsctx
for col in 0..<30 {
    guard rnd() % 3 == 0 else { continue }
    let start = Int(rnd() % 20)
    for row in start..<min(30, start + 3 + Int(rnd() % 8)) {
        let ch = String(chars[Int(rnd() % UInt64(chars.count))])
        let alpha = 0.10 * (1 - Double(row - start) / 11)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(srgbRed: 0.45, green: 0.55, blue: 0.58, alpha: alpha)]
        NSAttributedString(string: ch, attributes: attr).draw(at: CGPoint(x: 110 + col * 28, y: 900 - row * 30))
    }
}
NSGraphicsContext.restoreGraphicsState()

// The Claude spark.
let center = CGPoint(x: 512, y: 590)
let rays: [(Double, Double)] = [(0, 1.0), (31, 0.82), (64, 0.95), (95, 0.78), (128, 1.0), (160, 0.86),
                                (193, 0.97), (224, 0.8), (257, 0.93), (290, 0.84), (322, 0.98)]
let radius: CGFloat = 245
let lineW: CGFloat = 52
ctx.setLineCap(.round)
ctx.setLineWidth(lineW)
ctx.setStrokeColor(rgb(0xD97757))
for (angle, len) in rays {
    let a = (90 - angle) * .pi / 180
    let inner = radius * 0.02
    let outer = radius * CGFloat(len) - lineW / 2
    ctx.move(to: CGPoint(x: center.x + cos(a) * inner, y: center.y + sin(a) * inner))
    ctx.addLine(to: CGPoint(x: center.x + cos(a) * outer, y: center.y + sin(a) * outer))
    ctx.strokePath()
}

// A small bar chart along the bottom.
let heights: [CGFloat] = [70, 118, 92, 150, 120]
let barW: CGFloat = 54
let gap: CGFloat = 26
let totalW = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
var x = 512 - totalW / 2
for (i, h) in heights.enumerated() {
    let r = CGRect(x: x, y: 190, width: barW, height: h)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.setFillColor(i == 3 ? rgb(0x4C9AE6) : rgb(0xF4F2EC, 0.88))
    ctx.fillPath()
    x += barW + gap
}
ctx.restoreGState()

// Thin inner border.
ctx.addPath(CGPath(roundedRect: box.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 185, cornerHeight: 185, transform: nil))
ctx.setStrokeColor(rgb(0xFFFFFF, 0.08))
ctx.setLineWidth(3)
ctx.strokePath()

guard let img = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: img)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: out))
print("icon written to \(out)")
