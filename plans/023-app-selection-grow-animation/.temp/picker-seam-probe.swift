// Can a test process drive an NSPopUpButton's item action, read a cell's image rect, and read back a layer's
// keyframe animation, with no window and no running application?
import AppKit
import QuartzCore

final class Target: NSObject {
    nonisolated(unsafe) var picked: [String] = []
    @objc func pick(_ sender: NSMenuItem) { picked.append(sender.title) }
}

let target = Target()
let button = NSPopUpButton(frame: .zero, pullsDown: false)
button.isBordered = false
(button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
button.menu?.autoenablesItems = false

let icon = NSImage(size: NSSize(width: 17, height: 16), flipped: false) { rect in
    NSColor.red.setFill()
    rect.fill()
    return true
}
let closed = NSMenuItem(title: "Safari", action: nil, keyEquivalent: "")
closed.attributedTitle = NSAttributedString(
    string: "Safari", attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)])
closed.image = icon
button.menu?.addItem(closed)
button.selectItem(at: 0)
let size = button.intrinsicContentSize
button.frame = NSRect(origin: .zero, size: size)
print("intrinsic", size)
if let cell = button.cell as? NSPopUpButtonCell {
    print("imageRect", cell.imageRect(forBounds: button.bounds), "titleRect", cell.titleRect(forBounds: button.bounds))
}

// The open menu's items, then a pick through the item's action, two ways.
button.menu?.removeAllItems()
for name in ["Mail", "Music"] {
    let item = NSMenuItem(title: name, action: #selector(Target.pick(_:)), keyEquivalent: "")
    item.target = target
    button.menu?.addItem(item)
}
print("NSApp before", NSApp == nil ? "nil" : "exists")
button.menu?.performActionForItem(at: 0)
print("after performActionForItem", target.picked)
if let item = button.menu?.item(at: 1), let action = item.action {
    _ = (item.target as AnyObject?)?.perform(action, with: item)
}
print("after perform", target.picked)

// A layer animation, read back with no window.
let layer = CALayer()
layer.bounds = CGRect(x: 0, y: 0, width: 16, height: 16)
layer.actions = ["contents": NSNull(), "position": NSNull(), "hidden": NSNull(), "bounds": NSNull()]
let animation = CAKeyframeAnimation(keyPath: "transform")
animation.values = [0.4, 1.1, 1.0].map { NSValue(caTransform3D: CATransform3DMakeScale($0, $0, 1)) }
animation.keyTimes = [0, 0.5714, 1]
animation.duration = 0.35
layer.add(animation, forKey: "pick")
let read = layer.animation(forKey: "pick") as? CAKeyframeAnimation
print("animationKeys", layer.animationKeys() ?? [], "duration", read?.duration ?? -1,
      "scales", (read?.values as? [NSValue])?.map { $0.caTransform3DValue.m11 } ?? [])
layer.add(animation, forKey: "pick")
print("after re-add, keys", layer.animationKeys() ?? [])
print("NSApp after", NSApp == nil ? "nil" : "exists")
