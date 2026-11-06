// Probe: what does a gear turning once every 30 s cost the process, as a SwiftUI repeatForever rotation and as a Core
// Animation rotation on a layer? Shows a window with one 91 pt gear turning, waits a second for things to settle, then
// measures the process's CPU time and the main thread's over the next five seconds.
// Run: swift gear-cost.swift swiftui | ca | still
import AppKit
import SwiftUI

let mode = CommandLine.arguments.dropFirst().first ?? "still"
let period: Double = 30

let gearImage: NSImage = {
    let symbol = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(pointSize: 80, weight: .regular))!
    let image = NSImage(size: NSSize(width: 91, height: 91), flipped: false) { rect in
        symbol.draw(in: rect)
        return true
    }
    return image
}()

struct SwiftUIGear: View {
    @State private var turned = false
    var body: some View {
        Image(nsImage: gearImage)
            .resizable()
            .frame(width: 91, height: 91)
            .rotationEffect(.degrees(turned ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) { turned = true }
            }
    }
}

final class GearLayerView: NSView {
    let gear = CALayer()
    override var isFlipped: Bool { true }
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 91, height: 91))
        wantsLayer = true
        gear.contents = gearImage
        gear.contentsScale = 2
        gear.bounds = CGRect(x: 0, y: 0, width: 91, height: 91)
        gear.position = CGPoint(x: 45.5, y: 45.5)
        gear.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        gear.actions = ["transform": NSNull(), "contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(gear)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, mode.hasPrefix("ca") else { return }
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = 0
        turn.toValue = 2 * Double.pi
        turn.duration = period
        turn.repeatCount = .infinity
        layer?.sublayers?.first?.add(turn, forKey: "turn")
    }
}

struct CAGear: NSViewRepresentable {
    func makeNSView(context: Context) -> GearLayerView { GearLayerView() }
    func updateNSView(_ view: GearLayerView, context: Context) {}
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: GearLayerView, context: Context) -> CGSize? {
        CGSize(width: 91, height: 91)
    }
}

struct Root: View {
    var body: some View {
        VStack {
            Text("Probe: \(mode)")
            if mode == "swiftui" { SwiftUIGear() } else { CAGear() }
        }
        .padding(40)
        .background(Color.white)
    }
}

func processCPU() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1e6
    let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1e6
    return user + system
}

func mainThreadCPU() -> Double {
    var info = thread_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
    let thread = mach_thread_self()
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { return .nan }
    return Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1e6
        + Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1e6
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let hosting = NSHostingView(rootView: Root())
let window = NSWindow(
    contentRect: NSRect(origin: NSPoint(x: 300, y: 300), size: NSSize(width: 200, height: 200)),
    styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = hosting
window.setContentSize(hosting.fittingSize)
window.orderFrontRegardless()

/// `ca-hide`: orders the window out after a second and back in two seconds later, reading the gear layer's animation
/// keys and presentation angle at each step, and the process's CPU while hidden.
if mode == "ca-hide" {
    func gearViews(in view: NSView) -> [GearLayerView] {
        (view as? GearLayerView).map { [$0] } ?? view.subviews.flatMap { gearViews(in: $0) }
    }
    func report(_ label: String) {
        let view = gearViews(in: hosting).first
        let angle = (view?.gear.presentation()?.value(forKeyPath: "transform.rotation.z") as? Double) ?? .nan
        print("\(label): keys \(view?.gear.animationKeys() ?? []), presentation angle \(angle), visible \(window.isVisible)")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        report("before orderOut")
        window.orderOut(nil)
        let startProcess = processCPU()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            report("hidden for 2 s")
            print("process CPU while hidden \(String(format: "%.1f", (processCPU() - startProcess) * 1000)) ms")
            window.orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                report("2 s after orderFront")
                exit(0)
            }
        }
    }
    app.run()
}

DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    let startProcess = processCPU()
    let startMain = mainThreadCPU()
    func gearViews(in view: NSView) -> [GearLayerView] {
        (view as? GearLayerView).map { [$0] } ?? view.subviews.flatMap { gearViews(in: $0) }
    }
    let view = gearViews(in: hosting).first
    print("layer geometry flipped:", view?.layer?.isGeometryFlipped as Any); let angleAtStart = (view?.gear.presentation()?.value(forKeyPath: "transform.rotation.z") as? Double) ?? .nan
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        let process = processCPU() - startProcess
        let main = mainThreadCPU() - startMain
        let angle = (view?.gear.presentation()?.value(forKeyPath: "transform.rotation.z") as? Double) ?? .nan
        print(
            "mode \(mode): process CPU \(String(format: "%.1f", process * 1000)) ms, main thread CPU "
                + "\(String(format: "%.1f", main * 1000)) ms over 5 s; presentation angle \(angleAtStart) -> \(angle) rad")
        exit(0)
    }
}
app.run()
