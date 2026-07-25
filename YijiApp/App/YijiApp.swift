import SwiftUI

@main
struct YijiApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appModel = AppModel()

    @MainActor
    init() {
        AppTheme.configureSystemAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
                .tint(AppTheme.accent)
                .task {
                    await appModel.load()
                }
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await appModel.refreshCloudSnapshot()
                    }
                }
        }
    }
}
