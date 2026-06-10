import SwiftUI

@main
struct YijiApp: App {
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
        }
    }
}
