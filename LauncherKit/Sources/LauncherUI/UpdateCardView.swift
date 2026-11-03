import LauncherCore
import SwiftUI

/// The update card as one rounded group: its text on the left and its button on the right, in a row at least 42 pt
/// tall. While downloading, a bar runs under the row; while installing there is no button.
struct UpdateCardView: View {
    let card: UpdateCard
    let updateNow: () -> Void
    let cancel: () -> Void

    var body: some View {
        FormGroup {
            switch card {
            case .available(let version):
                row(Copy.updateAvailable(version), button: Copy.updateNowButton, action: updateNow)
            case .downloading(let version, let progress):
                row(Copy.updateDownloading(version), button: Copy.cancelButton, action: cancel)
                ProgressView(value: progress)
                    .padding(.bottom, 10)
            case .installing(let version):
                row(Copy.updateInstalling(version), button: nil, action: {})
            case .failed:
                row(Copy.updateFailed, button: Copy.tryAgainButton, action: updateNow)
            }
        }
    }

    private func row(_ text: String, button: String?, action: @escaping () -> Void) -> some View {
        FormRow {
            Text(text)
                .font(.system(size: 11))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let button {
                Button(button, action: action)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 6))
            }
        }
    }
}
