import CoreGraphics

enum ScreenRecordingPermission {
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func request() {
        _ = CGRequestScreenCaptureAccess()
    }
}
