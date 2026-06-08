import SwiftUI

struct RootTabView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        TabView(selection: Bindable(appModel).selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tag(AppTab.home)
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.systemImage)
            }

            NavigationStack {
                CaptureView()
            }
            .tag(AppTab.capture)
            .tabItem {
                Label(AppTab.capture.title, systemImage: AppTab.capture.systemImage)
            }

            NavigationStack {
                SearchView()
            }
            .tag(AppTab.search)
            .tabItem {
                Label(AppTab.search.title, systemImage: AppTab.search.systemImage)
            }

            NavigationStack {
                SettingsView()
            }
            .tag(AppTab.settings)
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
            }
            .badge(appModel.pendingReminders.isEmpty ? 0 : appModel.pendingReminders.count)
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
    }
}

enum AppTab: Hashable {
    case home
    case capture
    case search
    case settings

    var title: String {
        switch self {
        case .home:
            "首页"
        case .capture:
            "录入"
        case .search:
            "搜索"
        case .settings:
            "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "square.grid.2x2.fill"
        case .capture:
            "mic.circle.fill"
        case .search:
            "magnifyingglass.circle.fill"
        case .settings:
            "person.crop.circle.fill"
        }
    }
}

#Preview("App Tabs - iPhone 16 Pro") {
    PreviewSupport.canvas {
        RootTabView()
    }
}

#Preview("App Tabs - Dark") {
    PreviewSupport.canvas(colorScheme: .dark) {
        RootTabView()
    }
}
