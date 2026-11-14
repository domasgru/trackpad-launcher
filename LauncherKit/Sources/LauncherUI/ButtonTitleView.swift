import AppKit
import LauncherCore
import SwiftUI

/// A button's label. `.plain`: the text. `.progress`: the word, then dots in a box as wide as "…", as one accessibility
/// element labelled with the whole progress label, so VoiceOver reads "Checking…" and hears no dot change.
struct ButtonTitleView: View {
    let title: ButtonTitle
    @Environment(\.controlSize) private var controlSize

    var body: some View {
        switch title {
        case .plain(let text):
            Text(text)
        case .progress(let progress):
            let size = nsControlSize
            let font = ProgressDots.font(for: size)
            let box = ProgressDotsView.size(font: font)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(progress.word)
                ProgressDots(controlSize: size)
                    .frame(width: box.width, height: box.height)
                    .alignmentGuide(.firstTextBaseline) { _ in ceil(font.ascender) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(progress.label)
        }
    }

    private var nsControlSize: NSControl.ControlSize {
        switch controlSize {
        case .mini: .mini
        case .small: .small
        case .large: .large
        case .extraLarge: .large
        default: .regular
        }
    }
}
