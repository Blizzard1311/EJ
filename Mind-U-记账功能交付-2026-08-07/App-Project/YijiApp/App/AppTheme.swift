import SwiftUI
import UIKit

@MainActor
enum AppTheme {
    static let accent = Color(red: 0.44, green: 0.53, blue: 0.45)
    static let accentUIColor = UIColor(red: 0.44, green: 0.53, blue: 0.45, alpha: 1.0)
    static let canvas = Color(red: 0.969, green: 0.969, blue: 0.957)
    static let surface = Color.white
    static let surfaceMuted = Color(red: 0.941, green: 0.953, blue: 0.933)
    static let line = Color(red: 0.886, green: 0.890, blue: 0.867)
    static let ink = Color(red: 0.125, green: 0.137, blue: 0.122)
    static let muted = Color(red: 0.52, green: 0.54, blue: 0.51)
    static let reminder = Color(red: 0.85, green: 0.53, blue: 0.30)
    static let completed = Color(red: 0.37, green: 0.61, blue: 0.45)

    static func configureSystemAppearance() {
        configureTabBarAppearance()
        configureNavigationBarAppearance()
    }

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundEffect = nil
        appearance.backgroundColor = UIColor(red: 0.985, green: 0.985, blue: 0.975, alpha: 0.98)
        appearance.shadowColor = UIColor(red: 0.82, green: 0.83, blue: 0.80, alpha: 0.55)

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
        appearance.configureWithOpaqueBackground()
        appearance.backgroundEffect = nil
        appearance.backgroundColor = UIColor(red: 0.969, green: 0.969, blue: 0.957, alpha: 0.98)
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
