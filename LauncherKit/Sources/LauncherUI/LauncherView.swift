import AppKit
import LauncherCore
import SwiftUI

/// Four gesture rows, the hand toggle, a divider, then the hint while gestures are active or the trackpad
/// settings notice while they are not, and a bottom bar holding Quit.
struct LauncherView: View {
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 16) {
                ForEach(launcher.rows) { row in
                    GestureRowView(row: row, launcher: launcher, actions: actions)
                }
                HandModeToggle(launcher: launcher)
                Divider()
                switch launcher.activity {
                case .active:
                    HintText(handMode: launcher.handMode)
                case .inactive(let cause):
                    TrackpadSettingsNotice(cause: cause, openSettings: actions.openTrackpadSettings)
                }
            }
            .padding(16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.quaternary))

            HStack {
                Spacer()
                Button("Quit", action: actions.quit)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
            }
        }
        .padding(12)
        .frame(width: 266)
        .fixedSize(horizontal: true, vertical: true)
    }
}

/// A gesture row reads the model and sends one intent.
struct GestureRowView: View {
    let row: GestureRow
    let launcher: Launcher
    let actions: LauncherActions

    var body: some View {
        HStack {
            GestureIllustration(gesture: row.gesture, handMode: launcher.handMode)
            Spacer(minLength: 8)
            AppPicker(
                app: row.app,
                installedApps: actions.installedApps,
                choose: { launcher.setAssignment($0, for: row.gesture) },
                chooseOther: { actions.chooseOtherApp(row.gesture) })
                .fixedSize()
        }
    }
}

/// The illustrations are the repo's SVGs, shipped as bundle resources and drawn as template images so they
/// follow the label colour in light and dark. Left hand mirrors them horizontally.
struct GestureIllustration: View {
    let gesture: LauncherCore.Gesture
    let handMode: HandMode

    var body: some View {
        TemplateImage.view("gesture-\(gesture.fingerCount)")
            .scaleEffect(x: handMode == .left ? -1 : 1, y: 1)
            .accessibilityLabel("\(gesture.fingerCount)-finger gesture")
    }
}

enum TemplateImage {
    /// A missing resource draws nothing rather than failing: the window stays usable.
    static func nsImage(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg"),
            let image = NSImage(contentsOf: url)
        else { return nil }
        image.isTemplate = true
        return image
    }

    @ViewBuilder static func view(_ name: String) -> some View {
        if let image = nsImage(name) {
            Image(nsImage: image).renderingMode(.template).foregroundStyle(.primary)
        }
    }
}

struct HandModeToggle: View {
    let launcher: Launcher

    var body: some View {
        Picker(
            "Hand mode",
            selection: Binding(get: { launcher.handMode }, set: { launcher.setHandMode($0) })
        ) {
            Text("Left hand").tag(HandMode.left)
            Text("Right hand").tag(HandMode.right)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

struct HintText: View {
    let handMode: HandMode

    var body: some View {
        Text(
            "\(mark("thumb-mark")) Hold thumb on \(handMode.cornerName) corner, \(mark("other-finger-mark")) tap with 1, 2, 3 or 4 fingers anywhere to launch selected app"
        )
            .hintStyle()
    }

    private func mark(_ name: String) -> Image {
        Image(nsImage: TemplateImage.nsImage(name) ?? NSImage()).renderingMode(.template)
    }
}

struct TrackpadSettingsNotice: View {
    let cause: InactiveCause
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .hintStyle()
            Button("Trackpad settings…", action: openSettings)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }

    private var message: String {
        switch cause {
        case .noTrackpad:
            "No trackpad connected. Connect a trackpad to use gestures."
        case .settings(let conflicting):
            "Gestures are off while these trackpad settings are on: "
                + conflicting.settings.map(\.noticeName).formatted(.list(type: .and)) + "."
        }
    }
}

private extension View {
    func hintStyle() -> some View {
        font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
