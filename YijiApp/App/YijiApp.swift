import SwiftUI

@main
struct YijiApp: App {
    @State private var appModel = AppModel()

    @MainActor
    init() {
        AppTheme.configureSystemAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(appModel)
                .tint(AppTheme.accent)
                .task {
                    await appModel.load()
                }
        }
    }
}
