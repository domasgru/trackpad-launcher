import LauncherCore
import SwiftUI

/// The thumb corner group's last cell: the Automatic updates switch and the running version. One cell, so the grouped
/// form draws no divider inside it. Metrics from `plans/052-auto-update-toggle/design/auto-updates.json`. It has no
/// capability check: in a copy that never updates the switch only saves its value.
struct UpdatesRow: View {
    let updater: Updater

    /// The cell's height: the form's 10, 6, the title line, 4, the version line, 6, the form's 10.
    static let height: CGFloat = 66
    private static let titleLineHeight: CGFloat = 16
    private static let lineSpacing: CGFloat = 4
    private static let versionFontSize: CGFloat = 11
    private static let verticalPadding: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: Self.lineSpacing) {
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
        }
        .padding(.vertical, Self.verticalPadding)
        .formRow(height: Self.height)
    }
}
