// Renders an HTML page to a PNG with WebKit (same engine as Safari).
// Usage: swift render.swift <file-url> <out.png> [width] [height]
import Cocoa
import WebKit

let args = CommandLine.arguments
let url = URL(string: args[1])!
let out = URL(fileURLWithPath: args[2])
let w = CGFloat(Double(args.count > 3 ? args[3] : "1600")!)
let h = CGFloat(Double(args.count > 4 ? args[4] : "1000")!)

final class Renderer: NSObject, WKNavigationDelegate {
    let web: WKWebView
    let window: NSWindow

    override init() {
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        window.contentView = web
        window.setFrameOrigin(NSPoint(x: 0, y: 0)); window.level = .floating
        window.orderFrontRegardless()
        web.navigationDelegate = self
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let cfg = WKSnapshotConfiguration()
            cfg.rect = NSRect(x: 0, y: 0, width: w, height: h)
            cfg.snapshotWidth = NSNumber(value: Double(w * 2))
            webView.takeSnapshot(with: nil) { image, error in
                guard let image, let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    print("snapshot failed: \(String(describing: error))"); exit(1)
                }
                try! png.write(to: out)
                print("wrote \(out.path) \(rep.pixelsWide)x\(rep.pixelsHigh)")
                exit(0)
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let renderer = Renderer()
app.run()
