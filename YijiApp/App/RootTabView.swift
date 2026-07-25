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
            "记录"
        case .capture:
            "收纳"
        case .calendar:
            "日历"
        case .settings:
            "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "waveform.circle.fill"
        case .capture:
            "square.stack.3d.up.fill"
        case .calendar:
            "calendar.circle.fill"
        case .settings:
            "gearshape.fill"
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
