// Probe: the settings column as the design wants it, rendered offscreen to a PNG: the Accessibility card above the
// form (border, 216 pt message, filled blue button, the gear clipped in its top-right corner) and the screen recording
// hint under the Switch windows switch inside one Form row. Prints the column's fitting height.
// Run: swift layout.swift <state: both|none|card|hint> <gear: clip|mask>
// Writes /tmp/layout-<state>-<gear>.png
import AppKit
import SwiftUI

let state = CommandLine.arguments.dropFirst().first ?? "both"
let gearMode = CommandLine.arguments.dropFirst(2).first ?? "clip"

/// What the launcher model would hold. `live` starts with nothing showing and flips both on after the window shows,
/// to see whether the hosting view's fitting size is current in the same turn as the change.
@Observable final class Shown {
    var card: Bool
    var hint: Bool
    init(card: Bool, hint: Bool) { self.card = card; self.hint = hint }
}
let shown = Shown(card: state == "both" || state == "card", hint: state == "both" || state == "hint")

let gearImage: NSImage = {
    let symbol = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(pointSize: 80, weight: .thin))!
    return NSImage(size: NSSize(width: 91, height: 91), flipped: false) { rect in
        NSColor(white: 0.85, alpha: 1).set()
        symbol.draw(in: rect)
        return true
    }
}()

/// The gear on a layer of its own. `clip`: 91 × 91, clipped by the SwiftUI card. `mask`: as big as the card, clipping
/// itself to the card's rounded rect, the gear placed inside it.
final class GearLayerView: NSView {
    let gear = CALayer()
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        gear.contents = gearImage
        gear.contentsScale = 2
        gear.bounds = CGRect(x: 0, y: 0, width: 91, height: 91)
        gear.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        gear.actions = ["transform": NSNull(), "contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(gear)
        if gearMode == "mask" {
            layer?.masksToBounds = true
            layer?.cornerRadius = 12
        }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        if gearMode == "mask" {
            gear.position = CGPoint(x: 222 + 45.5, y: -23 + 45.5)
        } else {
            gear.position = CGPoint(x: 45.5, y: 45.5)
        }
    }
}

struct Gear: NSViewRepresentable {
    func makeNSView(context: Context) -> GearLayerView { GearLayerView() }
    func updateNSView(_ view: GearLayerView, context: Context) {}
}

struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1)))
    }
}

struct AccessibilityCard: View {
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 8) {
            Text("Allow Accessibility access to make trackpad gestures work reliably.")
                .font(.system(size: 11))
                .lineSpacing(1)
                .frame(maxWidth: 216, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings…") {}
                .buttonStyle(FilledButtonStyle())
        }
        .padding(.vertical, 8)
        .frame(minHeight: 42)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)

        if gearMode == "mask" {
            content
                .background { Gear() }
                .background(Color(nsColor: .quaternarySystemFill), in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 0xde / 255, green: 0xde / 255, blue: 0xde / 255), lineWidth: 1))
        } else {
            content
                .background(alignment: .topTrailing) {
                    Gear().frame(width: 91, height: 91).offset(x: 19, y: -23)
                }
                .background(Color(nsColor: .quaternarySystemFill), in: .rect(cornerRadius: 12))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 0xde / 255, green: 0xde / 255, blue: 0xde / 255), lineWidth: 1))
        }
    }
}

struct Illustration: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.92)).frame(width: 45, height: 28)
    }
}

struct SettingRow: View {
    let title: String
    var body: some View {
        Toggle(isOn: .constant(true)) {
            HStack(spacing: 10) {
                Illustration()
                Text(title)
            }
            .frame(height: 26)
        }
        .toggleStyle(.switch)
    }
}

struct ScreenRecordingHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            (Text(Image(systemName: "exclamationmark.triangle.fill")).foregroundStyle(Color(red: 1, green: 0.8, blue: 0))
                + Text(" Allow Screen Recording access to show previews in the window switcher."))
                .font(.system(size: 11))
                .lineSpacing(3)
                .frame(maxWidth: 219, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings…") {}
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 6))
        }
    }
}

struct Column: View {
    var body: some View {
        VStack(spacing: 20) {
            if shown.card { AccessibilityCard().padding(.horizontal, 16) }
            Form {
                Section {
                    HStack {
                        Illustration()
                        Spacer()
                        Text("Picker")
                    }
                    .frame(height: 26)
                    Toggle("Animate app launch", isOn: .constant(true)).toggleStyle(.switch)
                }
                Section {
                    SettingRow(title: "Switch recent")
                    VStack(alignment: .leading, spacing: 4) {
                        SettingRow(title: "Switch windows")
                        if shown.hint {
                            ScreenRecordingHint().padding(.leading, 55)
                        }
                    }
                    SettingRow(title: "Toggle recent")
                }
                Section {
                    Picker("Thumb corner", selection: .constant(0)) { Text("Top left").tag(0) }
                    Toggle("Hide background apps", isOn: .constant(false)).toggleStyle(.switch)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .padding(.top, -20)
            .padding(.bottom, -20)
            .padding(.horizontal, 16 - 20)
            .zIndex(-1)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("Quit Trackpad Launcher") {}.buttonStyle(.bordered)
                Button("Close") {}.buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(width: 326)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let hosting = NSHostingView(rootView: Column())
let window = NSWindow(
    contentRect: NSRect(origin: NSPoint(x: 200, y: 200), size: NSSize(width: 326, height: 600)),
    styleMask: [.borderless], backing: .buffered, defer: false)
window.appearance = NSAppearance(named: .aqua)
window.contentView = hosting
window.setContentSize(hosting.fittingSize)
window.orderFrontRegardless()

if state == "live" {
    // As the settings shell does: a fit observation that reads the fitting size when the model changes.
    let observation = Task { @MainActor in
        for await fit in Observations({ (card: shown.card, hint: shown.hint) }) {
            print("live: observation turn for card \(fit.card) hint \(fit.hint), fitting height \(hosting.fittingSize.height)")
        }
    }
    _ = observation
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        print("live: before the flip, fitting height \(hosting.fittingSize.height)")
        shown.hint = true
        print("live: hint on, same turn, fitting height \(hosting.fittingSize.height)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("live: hint on, 0.3 s later, fitting height \(hosting.fittingSize.height)")
            shown.card = true
            print("live: card on, same turn, fitting height \(hosting.fittingSize.height)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("live: card on, 0.3 s later, fitting height \(hosting.fittingSize.height)")
                shown.hint = false
                print("live: hint off, same turn, fitting height \(hosting.fittingSize.height)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("live: hint off, 0.3 s later, fitting height \(hosting.fittingSize.height)")
                    exit(0)
                }
            }
        }
    }
    app.run()
}

DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    let bounds = hosting.bounds
    let rep = hosting.bitmapImageRepForCachingDisplay(in: bounds)!
    hosting.cacheDisplay(in: bounds, to: rep)
    print("state \(state) gear \(gearMode): fitting height \(hosting.fittingSize.height), bounds \(bounds.size)")
    let path = "/tmp/layout-\(state)-\(gearMode).png"
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
    exit(0)
}
app.run()
