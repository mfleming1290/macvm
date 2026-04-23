import CoreGraphics
import Foundation

final class DisplayCoordinateMapper {
    private let lock = NSLock()
    private var displayFrame = CGRect(x: 0, y: 0, width: 1, height: 1)

    func update(captureConfiguration: CaptureConfiguration) {
        lock.lock()
        displayFrame = captureConfiguration.displayFrame
        lock.unlock()
    }

    func map(x normalizedX: Double, y normalizedY: Double) -> CGPoint {
        lock.lock()
        let frame = displayFrame
        lock.unlock()

        let x = frame.minX + frame.width * min(1, max(0, normalizedX))
        let y = frame.minY + frame.height * min(1, max(0, normalizedY))
        return CGPoint(x: x, y: y)
    }
}
