import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AgentAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("macvm Agent")
                    .font(.largeTitle.bold())
                Text("Screen streaming over WebRTC")
                    .foregroundStyle(.secondary)
            }

            StatusRow(
                title: "Screen Recording",
                value: appState.screenRecordingAllowed ? "Allowed" : "Not granted",
                isHealthy: appState.screenRecordingAllowed
            )

            StatusRow(
                title: "Accessibility",
                value: appState.accessibilityAllowed ? "Allowed" : "Not granted",
                isHealthy: appState.accessibilityAllowed
            )

            StatusRow(
                title: "Signaling",
                value: appState.serverStatus,
                isHealthy: appState.serverStatus.contains("Listening")
            )

            StatusRow(
                title: "Session",
                value: appState.sessionStatus,
                isHealthy: appState.sessionStatus == "Streaming"
            )

            DiagnosticsView(
                mediaDiagnostics: appState.mediaDiagnostics,
                controlDiagnostics: appState.controlDiagnostics
            )

            HStack {
                Button("Request Screen Recording Permission") {
                    appState.requestScreenRecordingPermission()
                }
                Button("Request Accessibility Permission") {
                    appState.requestAccessibilityPermission()
                }
                Button("Refresh Status") {
                    appState.refreshPermissionStatus()
                }
            }

            Text("Open the web client and connect to http://\(appState.localAddressHint):8080")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 560, alignment: .leading)
    }
}

private struct DiagnosticsView: View {
    let mediaDiagnostics: MediaDiagnostics
    let controlDiagnostics: ControlDiagnostics

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
            GridRow {
                Text("Capture")
                    .fontWeight(.semibold)
                Text("\(mediaDiagnostics.completeFrames)/\(mediaDiagnostics.captureFrames) complete, \(mediaDiagnostics.droppedFrames) dropped")
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Bridge")
                    .fontWeight(.semibold)
                Text("\(mediaDiagnostics.capturerFrames) capturer frames, \(mediaDiagnostics.sourceFrames) source frames")
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Frame")
                    .fontWeight(.semibold)
                Text(frameDescription)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Sender")
                    .fontWeight(.semibold)
                Text("\(mediaDiagnostics.senderAttached ? "attached" : "missing"), track \(mediaDiagnostics.senderTrackReadyState), ICE \(mediaDiagnostics.iceConnectionState)")
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Control")
                    .fontWeight(.semibold)
                Text("\(controlDiagnostics.channelState), \(controlDiagnostics.injectedEvents)/\(controlDiagnostics.receivedMessages) injected, resets \(controlDiagnostics.resetCount)")
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Input state")
                    .fontWeight(.semibold)
                Text("\(controlDiagnostics.pressedButtons) buttons, \(controlDiagnostics.pressedKeys) keys, error \(controlDiagnostics.lastError ?? "none")")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.monospacedDigit())
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var frameDescription: String {
        guard let width = mediaDiagnostics.lastFrameWidth, let height = mediaDiagnostics.lastFrameHeight else {
            return "none"
        }

        return "\(width)x\(height) \(mediaDiagnostics.lastPixelFormat ?? "unknown")"
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let isHealthy: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(isHealthy ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(title)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
