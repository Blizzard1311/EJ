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
                .environment(\.locale, appModel.appLanguage.locale)
                .tint(AppTheme.accent)
                .task {
                    await appModel.load()
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active, AppReleaseConfiguration.cloudSyncEnabled {
                        Task {
                            await appModel.refreshCloudSnapshot()
                        }
                    } else if newPhase != .active {
                        appModel.stopAllVoiceActivity()
                    }
                }
        }
    }
}
