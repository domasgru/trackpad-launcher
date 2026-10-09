import LauncherCore

/// The 96-byte MTTouch record. Only this file knows its layout; fields the app never reads are kept as padding.
struct MTTouchMirror {
    var frame: Int32 = 0
    var timestamp: Double = 0
    var identifier: Int32
    var state: Int32
    var fingerID: Int32 = 0
    var handID: Int32 = 0
    /// Origin bottom-left.
    var normalizedX: Float
    var normalizedY: Float
    var velocityX: Float = 0
    var velocityY: Float = 0
    var zTotal: Float = 0
    var padding9: Int32 = 0
    var angle: Float = 0
    var majorAxis: Float = 0
    var minorAxis: Float = 0
    var absoluteX: Float = 0
    var absoluteY: Float = 0
    var absoluteVelocityX: Float = 0
    var absoluteVelocityY: Float = 0
    var padding14: Int32 = 0
    var padding15: Int32 = 0
    var zDensity: Float = 0

    init(identifier: Int32, state: Int32, x: Float, y: Float) {
        self.identifier = identifier
        self.state = state
        normalizedX = x
        normalizedY = y
    }
}

extension TouchFrame {
    /// MTTouch[] to TouchFrame. Keeps states 3 (MakeTouch, a landing) and 4 (Touching) only, and maps the
    /// framework's bottom-left normalised origin to SurfacePoint's top-left one.
    init(parsing touches: UnsafeMutableRawPointer?, count: Int32, timestamp: Double, buttonDown: Bool) {
        var parsed: [Touch] = []
        if let touches, count > 0 {
            let records = UnsafeBufferPointer(
                start: touches.assumingMemoryBound(to: MTTouchMirror.self), count: Int(count))
            for record in records where record.state == 3 || record.state == 4 {
                parsed.append(
                    Touch(
                        id: TouchID(rawValue: record.identifier),
                        phase: record.state == 3 ? .landing : .down,
                        position: SurfacePoint(x: Double(record.normalizedX), y: 1 - Double(record.normalizedY))))
            }
        }
        self.init(time: FrameTime(seconds: timestamp), touches: parsed, buttonDown: buttonDown)
    }
}
