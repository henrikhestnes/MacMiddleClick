import CoreGraphics

/// Turns left clicks into middle clicks while `shouldConvert` says so, and posts synthetic middle clicks.
/// Both need Accessibility access.
final class ClickInterceptor {
    /// Asked on every left mouse down.
    var shouldConvert: () -> Bool = { false }
    /// Called on every left mouse down, converted or not.
    var onPress: () -> Void = {}

    private var tap: CFMachPort?
    // Once a press is converted, its drags and release must be converted too, whatever the fingers do.
    private var converting = false

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = [CGEventType.leftMouseDown, .leftMouseUp, .leftMouseDragged]
            .reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let interceptor = Unmanaged<ClickInterceptor>.fromOpaque(refcon!).takeUnretainedValue()
            return interceptor.handle(type, event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .leftMouseDown:
            onPress()
            converting = shouldConvert()
            if converting { convert(event, to: .otherMouseDown) }
        case .leftMouseDragged where converting:
            convert(event, to: .otherMouseDragged)
        case .leftMouseUp where converting:
            converting = false
            convert(event, to: .otherMouseUp)
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func convert(_ event: CGEvent, to type: CGEventType) {
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
    }

    /// Posts a middle click at the pointer.
    static func postMiddleClick() {
        let source = CGEventSource(stateID: .hidSystemState)
        let location = CGEvent(source: nil)?.location ?? .zero
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: .center)?
                .post(tap: .cghidEventTap)
        }
    }
}
