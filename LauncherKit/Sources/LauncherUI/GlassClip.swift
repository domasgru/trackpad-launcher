import AppKit

/// The glass alone leaves faint full-rectangle content behind its rounded corners, and the window shadow traces that
/// rectangle as a square outline. Clipping the content to the glass's shape makes everything outside the rounded
/// corners transparent, so the shadow follows the rounded edge.
func roundedClip(_ glass: NSGlassEffectView, cornerRadius: CGFloat) -> NSView {
    let clip = NSView()
    clip.wantsLayer = true
    clip.layer?.cornerRadius = cornerRadius
    clip.layer?.cornerCurve = .continuous
    clip.layer?.masksToBounds = true
    glass.translatesAutoresizingMaskIntoConstraints = false
    clip.addSubview(glass)
    NSLayoutConstraint.activate([
        glass.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
        glass.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
        glass.topAnchor.constraint(equalTo: clip.topAnchor),
        glass.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
    ])
    return clip
}
