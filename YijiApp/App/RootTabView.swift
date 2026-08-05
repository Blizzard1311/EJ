import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            NavigationStack {
                CaptureView()
            }
            .tag(AppTab.home)
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.systemImage)
            }

            NavigationStack {
                HomeView()
            }
            .tag(AppTab.capture)
            .tabItem {
                Label(AppTab.capture.title, systemImage: AppTab.capture.systemImage)
            }

            NavigationStack {
                CalendarView()
            }
            .tag(AppTab.calendar)
            .tabItem {
                Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage)
            }
            .badge(appModel.pendingReminders.isEmpty ? 0 : appModel.pendingReminders.count)

            NavigationStack {
                SettingsView()
            }
            .tag(AppTab.settings)
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
            }
        }
        .tint(AppTheme.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
    }
}

enum AppTab: Hashable {
    case home
    case capture
    case calendar
    case settings

    var title: String {
        switch self {
        case .home:
            AppLocalization.text("记录")
        case .capture:
            AppLocalization.text("收纳")
        case .calendar:
            AppLocalization.text("日历")
        case .settings:
            AppLocalization.text("设置")
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "mic"
        case .capture:
            "square.stack.3d.up"
        case .calendar:
            "calendar"
        case .settings:
            "gearshape"
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
