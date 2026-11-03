import AppKit
@testable import LauncherCore
import SwiftUI
import Testing
@testable import LauncherUI

/// Not a check: shows the picker on screen, hosted by SwiftUI like the settings window, with the Mac's real apps and
/// icons, then opens its menu and picks an app, so a screen recording shows what the user sees. Runs only with
/// PICKER_DEMO=1: `PICKER_DEMO=1 Scripts/test.sh --filter PickerDemo`.
@Suite struct PickerDemo {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PICKER_DEMO"] == "1"))
    func openAndPickOnScreen() async throws {
        let urls = ["/Applications", "/System/Applications"].flatMap { folder in
            ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [])
                .filter { $0.hasSuffix(".app") }.map { URL(filePath: folder).appending(path: $0) }
        }
        let entries = urls.map { url in
            AppEntry(
                bundleID: BundleID(rawValue: Bundle(url: url)?.bundleIdentifier ?? url.path), name: url.deletingPathExtension().lastPathComponent,
                url: url)
        }.sorted { $0.name < $1.name }
        NSApplication.shared.setActivationPolicy(.regular)
        let icons = AppIcons()
        let installed = InstalledApps(recent: [], others: entries)
        let start = entries.first { $0.name == "Safari" } ?? entries[0]
        let target = entries.max { $0.name.count < $1.name.count } ?? entries[1]
        let state = DemoState(current: .present(start))

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 326, height: 120), styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "Picker demo"
        window.contentView = NSHostingView(rootView: DemoRow(
            state: state, installed: installed, icons: icons))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
        print("DEMO start=\(start.name) target=\(target.name)")

        try await Task.sleep(for: .seconds(1.5))
        func popUp(in view: NSView) -> NSPopUpButton? {
            (view as? NSPopUpButton) ?? view.subviews.lazy.compactMap(popUp).first
        }
        let button = try #require(popUp(in: window.contentView!))
        let menu = try #require(button.menu)
        nonisolated(unsafe) let unsafeMenu = menu
        let timer = Timer(timeInterval: 1.0, repeats: false) { _ in
            MainActor.assumeIsolated {
                print("DEMO open: highlighted=\(unsafeMenu.highlightedItem?.title ?? "-")")
                unsafeMenu.cancelTracking()
                if let index = unsafeMenu.items.firstIndex(where: { $0.title == target.name }) {
                    unsafeMenu.performActionForItem(at: index)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        button.performClick(nil)
        try await Task.sleep(for: .seconds(2))
        window.close()
    }
}

@MainActor @Observable final class DemoState {
    var current: RowApp
    init(current: RowApp) { self.current = current }
}

struct DemoRow: View {
    let state: DemoState
    let installed: InstalledApps
    let icons: AppIcons

    var body: some View {
        HStack {
            Text("Gesture").font(.system(size: 13, weight: .medium))
            Spacer(minLength: 12)
            AppPicker(
                current: state.current, installedApps: installed,
                cachedIcon: { icons.iconDrawingIfMissing(for: $0) }, icon: { icons.iconDrawingIfMissing(for: $0) },
                choose: { choice in
                    guard case .app(let entry) = choice else { state.current = .unassigned; return nil }
                    state.current = .present(entry)
                    return entry
                },
                chooseOther: { _ in }, pickAnimation: { .shipped })
        }
        .padding(.horizontal, 20)
        .frame(width: 326, height: 120)
    }
}
