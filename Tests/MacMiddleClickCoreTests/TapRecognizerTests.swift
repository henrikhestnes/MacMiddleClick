import XCTest
@testable import MacMiddleClickCore

final class TapRecognizerTests: XCTestCase {
    private func fingers(_ count: Int, dx: Float = 0) -> [Contact] {
        (0..<count).map { Contact(id: Int32($0), x: 0.3 + Float($0) * 0.1 + dx, y: 0.5) }
    }

    func testThreeFingerTapIsRecognized() {
        var recognizer = TapRecognizer(fingers: 3)
        XCTAssertFalse(recognizer.process(fingers(1), at: 0))
        XCTAssertFalse(recognizer.process(fingers(3), at: 0.02))
        XCTAssertFalse(recognizer.process(fingers(2), at: 0.1))
        XCTAssertTrue(recognizer.process([], at: 0.12))
        XCTAssertFalse(recognizer.isTracking)
    }

    func testWrongFingerCountIsIgnored() {
        var recognizer = TapRecognizer(fingers: 3)
        _ = recognizer.process(fingers(2), at: 0)
        XCTAssertFalse(recognizer.process([], at: 0.1))
        _ = recognizer.process(fingers(4), at: 1)
        _ = recognizer.process(fingers(3), at: 1.05)
        XCTAssertFalse(recognizer.process([], at: 1.1))
    }

    func testSlowTapIsIgnored() {
        var recognizer = TapRecognizer(fingers: 3, maxDuration: 0.3)
        _ = recognizer.process(fingers(3), at: 0)
        XCTAssertFalse(recognizer.process([], at: 0.5))
    }

    func testMovementCancelsTap() {
        var recognizer = TapRecognizer(fingers: 3, maxMovement: 0.04)
        _ = recognizer.process(fingers(3), at: 0)
        _ = recognizer.process(fingers(3, dx: 0.1), at: 0.05)
        XCTAssertFalse(recognizer.process([], at: 0.1))
    }

    func testSmallJitterIsAllowed() {
        var recognizer = TapRecognizer(fingers: 3, maxMovement: 0.04)
        _ = recognizer.process(fingers(3), at: 0)
        _ = recognizer.process(fingers(3, dx: 0.01), at: 0.05)
        XCTAssertTrue(recognizer.process([], at: 0.1))
    }

    func testCancelSuppressesTapUntilNextGesture() {
        var recognizer = TapRecognizer(fingers: 3)
        _ = recognizer.process(fingers(3), at: 0)
        recognizer.cancel()
        XCTAssertFalse(recognizer.process([], at: 0.1))
        _ = recognizer.process(fingers(3), at: 1)
        XCTAssertTrue(recognizer.process([], at: 1.1))
    }

    func testFourFingerSetting() {
        var recognizer = TapRecognizer(fingers: 4)
        _ = recognizer.process(fingers(4), at: 0)
        XCTAssertTrue(recognizer.process([], at: 0.1))
    }
}
