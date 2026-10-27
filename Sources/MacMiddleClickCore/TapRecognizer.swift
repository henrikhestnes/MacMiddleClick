/// A single contact on a trackpad, in normalized device coordinates (0...1).
public struct Contact: Equatable {
    public var id: Int32
    public var x: Float
    public var y: Float

    public init(id: Int32, x: Float, y: Float) {
        self.id = id
        self.x = x
        self.y = y
    }
}

/// Recognizes a quick tap with exactly `fingers` fingers from a stream of touch frames.
///
/// A gesture runs from the first contact to the frame where no contacts remain. It counts as a tap
/// when it reached exactly `fingers` contacts, never more, finished within `maxDuration`, and no
/// finger moved further than `maxMovement` from where it landed.
public struct TapRecognizer {
    public var fingers: Int
    public var maxDuration: Double
    public var maxMovement: Float

    private var start: Double?
    private var origins: [Int32: (x: Float, y: Float)] = [:]
    private var peak = 0
    private var invalid = false

    public init(fingers: Int = 3, maxDuration: Double = 0.3, maxMovement: Float = 0.04) {
        self.fingers = fingers
        self.maxDuration = maxDuration
        self.maxMovement = maxMovement
    }

    /// Whether a gesture is in progress.
    public var isTracking: Bool { start != nil }

    /// Feeds one frame. Returns true on the frame that completes a tap.
    public mutating func process(_ contacts: [Contact], at time: Double) -> Bool {
        guard !contacts.isEmpty else {
            defer { reset() }
            guard let start, !invalid else { return false }
            return peak == fingers && time - start <= maxDuration
        }
        if start == nil { start = time }
        peak = max(peak, contacts.count)
        if peak > fingers { invalid = true }
        for contact in contacts {
            guard let origin = origins[contact.id] else {
                origins[contact.id] = (contact.x, contact.y)
                continue
            }
            let dx = contact.x - origin.x, dy = contact.y - origin.y
            if dx * dx + dy * dy > maxMovement * maxMovement { invalid = true }
        }
        return false
    }

    /// Prevents the current gesture from producing a tap, for example when it pressed the trackpad.
    public mutating func cancel() {
        if start != nil { invalid = true }
    }

    private mutating func reset() {
        start = nil
        origins.removeAll()
        peak = 0
        invalid = false
    }
}
