import XCTest
@testable import MacAgent

final class FrameSubmissionGateTests: XCTestCase {
    func testSubmitsFirstFrameImmediately() {
        var gate = FrameSubmissionGate(targetFramesPerSecond: 30)

        XCTAssertTrue(gate.shouldSubmit(timestampNs: 0))
    }

    func testDropsFramesThatArriveTooSoon() {
        var gate = FrameSubmissionGate(targetFramesPerSecond: 30)

        XCTAssertTrue(gate.shouldSubmit(timestampNs: 0))
        XCTAssertFalse(gate.shouldSubmit(timestampNs: 10_000_000))
        XCTAssertFalse(gate.shouldSubmit(timestampNs: 20_000_000))
        XCTAssertTrue(gate.shouldSubmit(timestampNs: 34_000_000))
    }

    func testResetClearsSubmissionHistory() {
        var gate = FrameSubmissionGate(targetFramesPerSecond: 30)

        XCTAssertTrue(gate.shouldSubmit(timestampNs: 100))
        XCTAssertFalse(gate.shouldSubmit(timestampNs: 1_000))

        gate.reset()

        XCTAssertTrue(gate.shouldSubmit(timestampNs: 1_000))
    }
}
