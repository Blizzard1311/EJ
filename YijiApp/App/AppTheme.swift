import SwiftUI
import UIKit

@MainActor
enum AppTheme {
    static let accent = Color(red: 0.23, green: 0.54, blue: 1.0)
    static let accentUIColor = UIColor(red: 0.23, green: 0.54, blue: 1.0, alpha: 1.0)

    static func configureSystemAppearance() {
        configureTabBarAppearance()
        configureNavigationBarAppearance()
    }

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.88)
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.05)

        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.selected.iconColor = accentUIColor
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: accentUIColor,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]
            itemAppearance.normal.iconColor = UIColor.secondaryLabel
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.secondaryLabel,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private static func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.72)
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = accentUIColor
    }
}
