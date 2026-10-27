import Foundation
import IOKit
import CMultitouch
import MacMiddleClickCore

/// Reads raw contacts from every trackpad through MultitouchSupport.framework.
///
/// Frames arrive on a framework thread, so all state is guarded by `lock`. Taps are reported on
/// the main thread.
final class TouchMonitor {
    static let shared = TouchMonitor()

    var onTap: (() -> Void)?
    private(set) var deviceCount = 0

    private let lock = NSLock()
    private var devices: CFArray?
    private var recognizers: [Int: TapRecognizer] = [:]
    private var counts: [Int: Int] = [:]
    private var fingers = 3
    private var tapEnabled = true
    private var notificationPort: IONotificationPortRef?
    private var running = false
    private var restartPending = false

    private init() {}

    func configure(fingers: Int, tapEnabled: Bool) {
        lock.withLock {
            self.fingers = fingers
            self.tapEnabled = tapEnabled
            recognizers.removeAll()
        }
    }

    /// The most fingers currently on any one trackpad.
    var fingerCount: Int { lock.withLock { counts.values.max() ?? 0 } }

    /// Stops the gestures in progress from ending in a tap.
    func cancelTap() {
        lock.withLock {
            for key in recognizers.keys { recognizers[key]?.cancel() }
        }
    }

    /// Starts listening. Returns false if the private framework is unavailable.
    @discardableResult
    func start() -> Bool {
        guard MTLoad() else { return false }
        stopDevices()
        running = true
        watchForDevices()
        guard let list = MTCopyDevices() else { return true }
        devices = list
        deviceCount = CFArrayGetCount(list)
        for index in 0..<deviceCount {
            MTStart(UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(list, index)), frameCallback)
        }
        return true
    }

    func stop() {
        running = false
        stopDevices()
    }

    private func stopDevices() {
        if let devices {
            for index in 0..<CFArrayGetCount(devices) {
                MTStop(UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(devices, index)), frameCallback)
            }
        }
        devices = nil
        deviceCount = 0
        lock.withLock {
            recognizers.removeAll()
            counts.removeAll()
        }
    }

    /// Restarts shortly after a trackpad connects, disconnects, or the Mac wakes, once the device settles.
    func scheduleRestart() {
        guard !restartPending else { return }
        restartPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
            restartPending = false
            if running { start() }
        }
    }

    fileprivate func handle(_ device: MTDeviceRef?, _ touches: UnsafePointer<MTTouch>?, _ count: Int, _ time: Double) {
        let key = Int(bitPattern: device)
        let contacts = (0..<count).compactMap { index in
            touches.map { Contact(id: $0[index].identifier, x: $0[index].normalized.position.x, y: $0[index].normalized.position.y) }
        }
        let tapped: Bool = lock.withLock {
            counts[key] = count
            guard tapEnabled else { return false }
            var recognizer = recognizers[key] ?? TapRecognizer(fingers: fingers)
            let tapped = recognizer.process(contacts, at: time)
            recognizers[key] = recognizer
            return tapped
        }
        if tapped { DispatchQueue.main.async { self.onTap?() } }
    }

    private func watchForDevices() {
        guard notificationPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notificationPort = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)
        let callback: IOServiceMatchingCallback = { _, iterator in
            drain(iterator)
            TouchMonitor.shared.scheduleRestart()
        }
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            IOServiceAddMatchingNotification(port, type, IOServiceMatching("AppleMultitouchDevice"), callback, nil, &iterator)
            // The iterator must be drained to arm the notification; existing devices are already started.
            drain(iterator)
        }
    }
}

private func drain(_ iterator: io_iterator_t) {
    while case let service = IOIteratorNext(iterator), service != 0 { IOObjectRelease(service) }
}

private let frameCallback: MTFrameCallback = { device, touches, count, timestamp, _ in
    TouchMonitor.shared.handle(device, touches, Int(count), timestamp)
    return 0
}
