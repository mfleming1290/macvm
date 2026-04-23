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
                title: "Signaling",
                value: appState.serverStatus,
                isHealthy: appState.serverStatus.contains("Listening")
            )

            StatusRow(
                title: "Session",
                value: appState.sessionStatus,
                isHealthy: appState.sessionStatus == "Streaming"
            )

            HStack {
                Button("Request Screen Recording Permission") {
                    appState.requestScreenRecordingPermission()
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
