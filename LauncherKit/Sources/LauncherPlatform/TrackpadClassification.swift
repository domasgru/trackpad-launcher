import LauncherCore

/// Magic Mouse and Touch Bar digitizers are multitouch devices but not trackpads. One table, one place:
/// the IORegistry "Product" string of the device must contain "Trackpad"; `MTDeviceIsBuiltIn` picks the kind.
func trackpadKind(product: String, isBuiltIn: Bool) -> TrackpadKind? {
    guard product.contains("Trackpad") else { return nil }
    return isBuiltIn ? .builtIn : .external
}
