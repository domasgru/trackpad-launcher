// Probe: where do a grouped Form's sections fall in the settings column, against the window's edges and its other parts?
// Fills the column's parts with solid colours and renders offscreen, then reads the edges from the pixels.
// Run: swift form-edges.swift <side-outset>
import AppKit
import SwiftUI

let sideOutset = CGFloat(Double(CommandLine.arguments.dropFirst().first ?? "0") ?? 0)
let showsCard = CommandLine.arguments.count < 3
let marginOverride: CGFloat? = ProcessInfo.processInfo.environment["CM"].flatMap { Double($0) }.map { CGFloat($0) }
let marginPlacement: ContentMarginPlacement = ProcessInfo.processInfo.environment["CMP"] == "all" ? .automatic : .scrollContent

struct Column: View {
    var body: some View {
        VStack(spacing: 20) {
            if showsCard { Color.green.frame(height: 46).padding(.horizontal, 16) }
            Form {
                Section { Toggle("Animate app launch", isOn: .constant(true)).toggleStyle(.switch) }
                    .listRowBackground(Color.red)
                Section {
                    Picker("Thumb corner", selection: .constant(0)) { Text("Top left").tag(0) }
                }
                .listRowBackground(Color.red)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, marginOverride, for: marginPlacement)
            .padding(.top, -20)
            .padding(.bottom, -20)
            .padding(.horizontal, -sideOutset)
            .zIndex(-1)
            Color.blue.frame(height: 46).padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(width: 326)
        .fixedSize(horizontal: true, vertical: false)
        .ignoresSafeArea().background(Color.white)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let hosting = NSHostingView(rootView: Column())
let window = NSWindow(
    contentRect: NSRect(origin: NSPoint(x: 200, y: 200), size: NSSize(width: 326, height: 400)),
    styleMask: [.borderless], backing: .buffered, defer: false)
window.contentView = hosting
window.setContentSize(hosting.fittingSize)
window.orderFrontRegardless()

DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    let bounds = hosting.bounds
    let rep = hosting.bitmapImageRepForCachingDisplay(in: bounds)!
    hosting.cacheDisplay(in: bounds, to: rep)
    let scale = CGFloat(rep.pixelsWide) / bounds.width
    print("window", bounds.size, "scale", scale)

    func kind(_ x: Int, _ y: Int) -> String {
        guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return "?" }
        let (r, g, b) = (c.redComponent, c.greenComponent, c.blueComponent)
        if g > r + 0.2, g > b + 0.2 { return "card" }
        if b > r + 0.2, b > g + 0.2 { return "buttons" }
        if r == g, g == b, r < 0.995, r > 0.8 { return "section" }; if abs(r - g) < 0.02, abs(g - b) < 0.02, r < 0.995, r > 0.8 { return "section" }
        return "-"
    }
    func spans(_ line: [String]) -> [String] {
        var out: [String] = []
        var start = 0
        for i in 1...line.count where i == line.count || line[i] != line[start] {
            out.append("\(line[start]) \(CGFloat(start) / scale)..\(CGFloat(i) / scale)")
            start = i
        }
        return out
    }
    let midX = rep.pixelsWide / 2
    print("vertical:", spans((0..<rep.pixelsHigh).map { kind(midX, $0) }))
    for name in ["section", "card", "buttons"] {
        guard let y = (0..<rep.pixelsHigh).first(where: { kind(midX, $0) == name }) else { continue }
        print("horizontal \(name):", spans((0..<rep.pixelsWide).map { kind($0, y + Int(18 * scale)) }))
    }
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/tmp/form-edges.png"))
    exit(0)
}
app.run()
