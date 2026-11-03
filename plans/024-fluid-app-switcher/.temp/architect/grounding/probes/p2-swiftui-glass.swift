// Probe P2: does SwiftUI's glass (GlassEffectContainer + .glassEffect, including a custom Shape)
// morph in the render server, or does SwiftUI run in-process per display frame while it animates?
// Counts main run loop wake-ups and custom Shape.path(in:) calls during a 1.2 s spring, lists
// CA animations on the SDF element layers mid-animation, and captures the window at rest and mid-way.
//
// Build: swiftc -swift-version 5 -parse-as-library -O p2-swiftui-glass.swift -o /tmp/tl-probe-024/p2
// Run:   /tmp/tl-probe-024/p2 /tmp/tl-probe-024/out-c

import AppKit
import SwiftUI
import QuartzCore

final class Counters { static var pathCalls = 0 }

struct Blob: Shape {
    var bulge: CGFloat
    var animatableData: CGFloat { get { bulge } set { bulge = newValue } }
    func path(in rect: CGRect) -> Path {
        Counters.pathCalls += 1
        var p = Path()
        p.addEllipse(in: rect.insetBy(dx: -bulge, dy: -bulge / 2))
        return p
    }
}

final class Model: ObservableObject {
    @Published var moved = false
}

struct Row: View {
    @ObservedObject var model: Model
    var body: some View {
        GlassEffectContainer(spacing: 40) {
            HStack(spacing: 16) {
                Circle().fill(.clear).frame(width: 60, height: 60).glassEffect(.regular, in: Circle())
                Circle().fill(.clear).frame(width: 60, height: 60).glassEffect(.regular, in: Circle())
                    .offset(x: model.moved ? 40 : 0)
                Color.clear.frame(width: 88, height: 88)
                    .glassEffect(.regular, in: Blob(bulge: model.moved ? 24 : 0))
                Circle().fill(.clear).frame(width: 60, height: 60).glassEffect(.regular, in: Circle())
            }
            .padding(30)
        }
    }
}

final class WakeCounter {
    var count = 0
    var observer: CFRunLoopObserver?
    func start() {
        count = 0
        observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.afterWaiting.rawValue, true, 0) { [weak self] _, _ in
            self?.count += 1
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    func stop() -> Int {
        if let o = observer { CFRunLoopRemoveObserver(CFRunLoopGetMain(), o, .commonModes) }
        return count
    }
}

func cpuMS() -> Double {
    var u = rusage()
    getrusage(RUSAGE_SELF, &u)
    return Double(u.ru_utime.tv_sec + u.ru_stime.tv_sec) * 1000 + Double(u.ru_utime.tv_usec + u.ru_stime.tv_usec) / 1000
}

func allLayers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(allLayers) }

@main
struct Probe {
    static func main() {
        let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/tl-probe-024/out-c"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let size = NSSize(width: 520, height: 180)
        let screen = NSScreen.main!.frame
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .white
        panel.level = .floating
        let model = Model()
        let host = NSHostingView(rootView: Row(model: model))
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
        panel.orderFrontRegardless()

        func capture(_ name: String) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-o", "-l", String(panel.windowNumber), "\(outDir)/swiftui-\(name).png"]
            try? p.run()
            p.waitUntilExit()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            capture("rest")
            let classes = Set(allLayers(host.layer!).map { NSStringFromClass(type(of: $0)) })
            print("layer classes at rest: \(classes.sorted())")
            let counter = WakeCounter()
            let pathBefore = Counters.pathCalls
            let cpu0 = cpuMS()
            counter.start()
            withAnimation(.spring(duration: 1.2, bounce: 0.3)) { model.moved = true }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { capture("mid") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                for l in allLayers(host.layer!) where NSStringFromClass(type(of: l)).contains("SDF") {
                    print("\(NSStringFromClass(type(of: l))) frame=\(l.frame) anims=\(l.animationKeys() ?? [])")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                print("process CPU during the animation window: \(String(format: "%.1f", cpuMS() - cpu0)) ms, including the capture spawn")
                let wakes = counter.stop()
                print("SwiftUI spring: main run loop wake-ups in 1.6 s: \(wakes), Shape.path calls: \(Counters.pathCalls - pathBefore)")
                capture("end")
                app.terminate(nil)
            }
        }
        app.run()
    }
}
