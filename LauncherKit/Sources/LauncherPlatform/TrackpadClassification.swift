import LauncherCore

/// Magic Mouse and Touch Bar digitizers are multitouch devices but not trackpads. One table, one place:
/// the IORegistry "Product" string of the device must contain "Trackpad"; `MTDeviceIsBuiltIn` picks the kind.
func trackpadKind(product: String, isBuiltIn: Bool) -> TrackpadKind? {
    guard product.contains("Trackpad") else { return nil }
    return isBuiltIn ? .builtIn : .external
}

/// The listed devices to run, in the listing's order, each with the corner of the entry that carries its ID. A listed
/// device no entry names is left out, and an entry no listed device carries runs nothing, so a device runs iff it was
/// asked for and then has its corner: there is no fallback corner to get wrong. Internal and pure.
func devicesToRun<Device>(
    _ listed: [(device: Device, trackpad: Trackpad)], _ runs: [TrackpadRun]
) -> [(device: Device, trackpad: Trackpad, corner: ThumbCorner)] {
    let corners = Dictionary(runs.map { ($0.trackpad.id, $0.corner) }, uniquingKeysWith: { first, _ in first })
    return listed.compactMap { listed in corners[listed.trackpad.id].map { (listed.device, listed.trackpad, $0) } }
}
