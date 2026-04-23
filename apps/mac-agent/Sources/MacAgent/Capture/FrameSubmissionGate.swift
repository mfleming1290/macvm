import Foundation

struct FrameSubmissionGate {
    private(set) var lastSubmittedTimestampNs: Int64?
    let targetFramesPerSecond: Int

    init(targetFramesPerSecond: Int) {
        self.targetFramesPerSecond = max(1, targetFramesPerSecond)
    }

    mutating func shouldSubmit(timestampNs: Int64) -> Bool {
        guard let lastSubmittedTimestampNs else {
            self.lastSubmittedTimestampNs = timestampNs
            return true
        }

        let minimumDeltaNs = Int64(1_000_000_000 / targetFramesPerSecond)
        guard timestampNs - lastSubmittedTimestampNs >= minimumDeltaNs else {
            return false
        }

        self.lastSubmittedTimestampNs = timestampNs
        return true
    }

    mutating func reset() {
        lastSubmittedTimestampNs = nil
    }
}
