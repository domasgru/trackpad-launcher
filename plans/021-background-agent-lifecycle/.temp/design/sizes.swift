import AppKit

let app = NSApplication.shared
for size in [NSControl.ControlSize.mini, .small, .regular] {
    let toggle = NSSwitch()
    toggle.controlSize = size
    let button = NSButton(title: "Close", target: nil, action: nil)
    button.bezelStyle = .push
    button.controlSize = size
    let segments = NSSegmentedControl(
        labels: ["Left thumb", "Right thumb"], trackingMode: .selectOne, target: nil, action: nil)
    segments.controlSize = size
    let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    popup.isBordered = false
    popup.controlSize = size
    popup.addItem(withTitle: "Notes")
    print(
        size.rawValue, "switch", toggle.fittingSize, "button", button.fittingSize, "segments", segments.fittingSize,
        "borderless popup", popup.intrinsicContentSize)
}
