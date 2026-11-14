import LauncherCore
import SwiftUI

/// The thumb corner group's last cell: the Automatic updates switch, the running version and *Check for updates…*. One
/// cell, so the grouped form draws no divider inside it, 98 pt in every state. Metrics from
/// `plans/052-auto-update-toggle/design/auto-updates.json`. It has no capability check: in a copy that never updates the
/// switch only saves its value and the button answers with an alert.
struct UpdatesRow: View {
    let updater: Updater

    /// The cell's height: the form's 10, 6, the title line, 4, the version line, 8, the button, 6, the form's 10.
    static let height: CGFloat = 98
    static let buttonWidth: CGFloat = 162
    private static let buttonHeight: CGFloat = 24
    private static let buttonRadius: CGFloat = 6
    private static let titleLineHeight: CGFloat = 16
    private static let lineSpacing: CGFloat = 4
    private static let buttonSpacing: CGFloat = 8
    private static let versionFontSize: CGFloat = 11
    private static let versionLineHeight: CGFloat = 14
    private static let verticalPadding: CGFloat = 6

    var body: some View {
        let button = UpdatesPreview.checkButton(updater.checkButton)
        VStack(alignment: .leading, spacing: 0) {
            Toggle(
                isOn: Binding(
                    get: { updater.isAutomaticUpdatesOn }, set: { updater.setAutomaticUpdates(on: $0) })
            ) {
                Text(Copy.automaticUpdatesRow)
            }
            .toggleStyle(.switch)
            .frame(height: Self.titleLineHeight)
            Text(Copy.currentVersion(updater.version))
                .font(.system(size: Self.versionFontSize))
                .foregroundStyle(.secondary)
                .frame(height: Self.versionLineHeight)
                .padding(.top, Self.lineSpacing)
            Button {
                updater.checkForUpdates()
            } label: {
                ButtonTitleView(title: button.title).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: Self.buttonRadius))
            .disabled(!button.isEnabled)
            .frame(width: Self.buttonWidth, height: Self.buttonHeight)
            .padding(.top, Self.buttonSpacing)
        }
        .padding(.vertical, Self.verticalPadding)
        .formRow(height: Self.height)
    }
}
