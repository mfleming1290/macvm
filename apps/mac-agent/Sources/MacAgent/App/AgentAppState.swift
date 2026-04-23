import Foundation

@MainActor
final class AgentAppState: ObservableObject {
    @Published var screenRecordingAllowed = ScreenRecordingPermission.isGranted
    @Published var serverStatus = "Starting"
    @Published var sessionStatus = "Waiting for viewer"
    @Published var localAddressHint = "localhost"
    @Published var mediaDiagnostics = MediaDiagnostics.empty

    private let sessionManager: SessionManager
    private var signalingServer: SignalingServer?

    init() {
        self.sessionManager = SessionManager()

        sessionManager.onSessionStatusChanged = { [weak self] status in
            Task { @MainActor in
                self?.sessionStatus = status
            }
        }
    }

    func start() async {
        refreshPermissionStatus()
        localAddressHint = NetworkAddress.localIPv4Address() ?? "localhost"

        let server = SignalingServer(port: 8080, sessionManager: sessionManager) { [weak self] status in
            Task { @MainActor in
                self?.serverStatus = status
            }
        }
        signalingServer = server

        do {
            try server.start()
        } catch {
            serverStatus = "Failed: \(error.localizedDescription)"
        }

        await refreshMediaDiagnosticsLoop()
    }

    func refreshPermissionStatus() {
        screenRecordingAllowed = ScreenRecordingPermission.isGranted
    }

    func requestScreenRecordingPermission() {
        ScreenRecordingPermission.request()
        refreshPermissionStatus()
    }

    private func refreshMediaDiagnosticsLoop() async {
        while !Task.isCancelled {
            mediaDiagnostics = sessionManager.mediaDiagnostics
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
