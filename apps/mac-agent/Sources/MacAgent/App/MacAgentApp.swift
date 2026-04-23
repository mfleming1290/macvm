import SwiftUI

@main
struct MacAgentApp: App {
    @StateObject private var appState = AgentAppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.start()
                }
        }
    }
}
