import Foundation

struct MediaDiagnostics: Codable {
    var captureFrames: Int
    var completeFrames: Int
    var submittedFrames: Int
    var droppedFrames: Int
    var droppedIncompleteFrames: Int
    var droppedPacingFrames: Int
    var droppedBackpressureFrames: Int
    var targetFramesPerSecond: Int
    var capturerFrames: Int
    var sourceFrames: Int
    var lastFrameWidth: Int?
    var lastFrameHeight: Int?
    var lastPixelFormat: String?
    var lastTimestampNs: Int64?
    var sourceDisplayWidth: Int?
    var sourceDisplayHeight: Int?
    var selectedStreamMaxLongEdge: Int?
    var selectedBitrateBps: Int?
    var senderAttached: Bool
    var senderTrackEnabled: Bool
    var senderTrackReadyState: String
    var localCandidates: Int
    var signalingState: String
    var iceConnectionState: String

    enum CodingKeys: String, CodingKey {
        case captureFrames
        case completeFrames
        case submittedFrames
        case droppedFrames
        case droppedIncompleteFrames
        case droppedPacingFrames
        case droppedBackpressureFrames
        case targetFramesPerSecond
        case capturerFrames
        case sourceFrames
        case lastFrameWidth
        case lastFrameHeight
        case lastPixelFormat
        case lastTimestampNs
        case sourceDisplayWidth
        case sourceDisplayHeight
        case selectedStreamMaxLongEdge
        case selectedBitrateBps
        case senderAttached
        case senderTrackEnabled
        case senderTrackReadyState
        case localCandidates
        case signalingState
        case iceConnectionState
    }

    static let empty = MediaDiagnostics(
        captureFrames: 0,
        completeFrames: 0,
        submittedFrames: 0,
        droppedFrames: 0,
        droppedIncompleteFrames: 0,
        droppedPacingFrames: 0,
        droppedBackpressureFrames: 0,
        targetFramesPerSecond: 0,
        capturerFrames: 0,
        sourceFrames: 0,
        lastFrameWidth: nil,
        lastFrameHeight: nil,
        lastPixelFormat: nil,
        lastTimestampNs: nil,
        sourceDisplayWidth: nil,
        sourceDisplayHeight: nil,
        selectedStreamMaxLongEdge: nil,
        selectedBitrateBps: nil,
        senderAttached: false,
        senderTrackEnabled: false,
        senderTrackReadyState: "none",
        localCandidates: 0,
        signalingState: "new",
        iceConnectionState: "new"
    )

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(captureFrames, forKey: .captureFrames)
        try container.encode(completeFrames, forKey: .completeFrames)
        try container.encode(submittedFrames, forKey: .submittedFrames)
        try container.encode(droppedFrames, forKey: .droppedFrames)
        try container.encode(droppedIncompleteFrames, forKey: .droppedIncompleteFrames)
        try container.encode(droppedPacingFrames, forKey: .droppedPacingFrames)
        try container.encode(droppedBackpressureFrames, forKey: .droppedBackpressureFrames)
        try container.encode(targetFramesPerSecond, forKey: .targetFramesPerSecond)
        try container.encode(capturerFrames, forKey: .capturerFrames)
        try container.encode(sourceFrames, forKey: .sourceFrames)
        try container.encode(lastFrameWidth, forKey: .lastFrameWidth)
        try container.encode(lastFrameHeight, forKey: .lastFrameHeight)
        try container.encode(lastPixelFormat, forKey: .lastPixelFormat)
        try container.encode(lastTimestampNs, forKey: .lastTimestampNs)
        try container.encode(sourceDisplayWidth, forKey: .sourceDisplayWidth)
        try container.encode(sourceDisplayHeight, forKey: .sourceDisplayHeight)
        try container.encode(selectedStreamMaxLongEdge, forKey: .selectedStreamMaxLongEdge)
        try container.encode(selectedBitrateBps, forKey: .selectedBitrateBps)
        try container.encode(senderAttached, forKey: .senderAttached)
        try container.encode(senderTrackEnabled, forKey: .senderTrackEnabled)
        try container.encode(senderTrackReadyState, forKey: .senderTrackReadyState)
        try container.encode(localCandidates, forKey: .localCandidates)
        try container.encode(signalingState, forKey: .signalingState)
        try container.encode(iceConnectionState, forKey: .iceConnectionState)
    }
}
