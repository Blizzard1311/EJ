import CoreLocation
import Foundation
import OSLog
import UIKit
import WeatherKit

struct CalendarDayWeather: Equatable {
    let date: Date
    let symbolName: String
    let conditionDescription: String
    let temperatureBandDescription: String
    let highTemperatureText: String
    let lowTemperatureText: String
    let accentColor: UIColor

    var summaryLine: String {
        "\(conditionDescription) · \(temperatureBandDescription)"
    }

    var temperatureLine: String {
        AppLocalization.format("weather.temperature_range", highTemperatureText, lowTemperatureText)
    }
}

@MainActor
final class CalendarWeatherModel: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case ready
        case needsAuthorization
        case denied
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var weatherByDate: [Date: CalendarDayWeather] = [:]

    private let calendar: Calendar
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.blizzard1311.yiji",
        category: "CalendarWeather"
    )
    private let locationManager: CLLocationManager
    private let weatherService: WeatherService
    private let refreshInterval: TimeInterval = 30 * 60

    private var refreshTask: Task<Void, Never>?
    private var lastRefreshDate: Date?
    private var authorizationRequestInFlight = false
    private var locationRequestInFlight = false
    private var weatherRequestRevision = 0
    private var isWeatherRefreshInFlight: Bool {
        refreshTask != nil
    }

    init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        locationManager: CLLocationManager = CLLocationManager(),
        weatherService: WeatherService = WeatherService()
    ) {
        self.calendar = calendar
        self.locationManager = locationManager
        self.weatherService = weatherService
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    deinit {
        refreshTask?.cancel()
    }

    var statusText: String {
        switch state {
        case .idle, .needsAuthorization:
            return AppLocalization.text("开启定位")
        case .loading:
            return AppLocalization.text("天气更新中")
        case .ready:
            return AppLocalization.text("天气已更新")
        case .denied:
            return AppLocalization.text("定位未开启")
        case .failed(let message):
            return message
        }
    }

    var statusIconName: String {
        switch state {
        case .idle, .needsAuthorization:
            return "location"
        case .loading:
            return "cloud.sun"
        case .ready:
            return "cloud.sun.fill"
        case .denied:
            return "location.slash"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    var actionTitle: String? {
        switch state {
        case .idle, .needsAuthorization, .failed:
            return AppLocalization.text("获取天气")
        case .ready:
            return AppLocalization.text("刷新")
        case .denied, .loading:
            return nil
        }
    }

    var shouldOfferSettings: Bool {
        state == .denied
    }

    func activate() {
        emitDebugTrace("activate status=\(locationManager.authorizationStatus.rawValue)")
        handleAuthorizationStatus(locationManager.authorizationStatus, forceRefresh: false)
    }

    func refresh() {
        emitDebugTrace("refresh status=\(locationManager.authorizationStatus.rawValue)")
        handleAuthorizationStatus(locationManager.authorizationStatus, forceRefresh: true)
    }

    func dayWeather(for date: Date) -> CalendarDayWeather? {
        weatherByDate[calendar.startOfDay(for: date)]
    }

    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus, forceRefresh: Bool) {
        switch status {
        case .notDetermined:
            state = .needsAuthorization
            guard !authorizationRequestInFlight else {
                emitDebugTrace("authorization request already in flight")
                return
            }
            authorizationRequestInFlight = true
            emitDebugTrace("requesting when-in-use authorization")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocationIfNeeded(forceRefresh: forceRefresh, trigger: "requesting location for weather refresh")
        case .restricted, .denied:
            emitDebugTrace("location authorization denied or restricted")
            authorizationRequestInFlight = false
            locationRequestInFlight = false
            state = .denied
        @unknown default:
            authorizationRequestInFlight = false
            locationRequestInFlight = false
            state = .failed("天气权限状态异常，请稍后重试。")
        }
    }

    private var shouldRefreshWeather: Bool {
        guard let lastRefreshDate else { return true }
        if weatherByDate.isEmpty {
            return true
        }
        return Date().timeIntervalSince(lastRefreshDate) >= refreshInterval
    }

    private func requestLocationIfNeeded(forceRefresh: Bool, trigger: String) {
        guard forceRefresh || shouldRefreshWeather else {
            if !weatherByDate.isEmpty {
                state = .ready
            }
            return
        }

        guard !locationRequestInFlight else {
            emitDebugTrace("location request already in flight")
            return
        }

        guard !isWeatherRefreshInFlight else {
            emitDebugTrace("weather refresh already in flight")
            state = .loading
            return
        }

        state = .loading
        locationRequestInFlight = true
        emitDebugTrace(trigger)
        locationManager.requestLocation()
    }

    private func loadWeather(for location: CLLocation) {
        refreshTask?.cancel()
        weatherRequestRevision += 1
        let revision = weatherRequestRevision
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                emitDebugTrace("loading weather for authorized location")
                let weather = try await weatherService.weather(for: location)
                try Task.checkCancellation()

                let dailyWeather = Dictionary(
                    uniqueKeysWithValues: weather.dailyForecast.forecast.prefix(10).map { day in
                        let normalizedDate = calendar.startOfDay(for: day.date)
                        return (normalizedDate, makeDayWeather(from: day, normalizedDate: normalizedDate))
                    }
                )

                weatherByDate = dailyWeather
                lastRefreshDate = Date()
                state = .ready
                emitDebugTrace("loaded weather days=\(dailyWeather.count)")
            } catch is CancellationError {
                logger.debug("Cancelled calendar weather refresh.")
                emitDebugTrace("weather refresh cancelled")
            } catch {
                logger.error("Failed to load weather: \(error.localizedDescription, privacy: .public)")
                let message = formattedWeatherErrorMessage(for: error)
                emitDebugTrace(
                    "weather refresh failed domain=\((error as NSError).domain) code=\((error as NSError).code) message=\(message) details=\(debugErrorDescription(for: error))"
                )
                state = .failed(message)
            }

            if revision == weatherRequestRevision {
                refreshTask = nil
            }
        }
    }

    private func formattedWeatherErrorMessage(for error: Error) -> String {
        let localizedDescription = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackDescription = localizedDescription.isEmpty ? String(describing: error) : localizedDescription

        if fallbackDescription.contains("WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors") {
            return AppLocalization.text("WeatherKit 认证失败，请确认开发者后台的 WeatherKit 能力和描述文件已生效。")
        }

        return AppLocalization.format("weather.error", fallbackDescription)
    }

    private func debugErrorDescription(for error: Error) -> String {
        let nsError = error as NSError
        let localizedDescription = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawDescription = String(describing: error).trimmingCharacters(in: .whitespacesAndNewlines)
        let description = localizedDescription.isEmpty ? rawDescription : localizedDescription
        return description.replacingOccurrences(of: "\n", with: " ")
    }

    private func emitDebugTrace(_ message: String) {
#if DEBUG
        logger.debug("\(message, privacy: .private(mask: .hash))")
#endif
    }

    private func makeDayWeather(from day: DayWeather, normalizedDate: Date) -> CalendarDayWeather {
        let highCelsius = Int(day.highTemperature.converted(to: .celsius).value.rounded())
        let lowCelsius = Int(day.lowTemperature.converted(to: .celsius).value.rounded())

        return CalendarDayWeather(
            date: normalizedDate,
            symbolName: day.symbolName,
            conditionDescription: Self.conditionDescription(for: day.condition),
            temperatureBandDescription: Self.temperatureBandDescription(highCelsius: highCelsius, lowCelsius: lowCelsius),
            highTemperatureText: "\(highCelsius)°",
            lowTemperatureText: "\(lowCelsius)°",
            accentColor: Self.temperatureTintColor(highCelsius: highCelsius, lowCelsius: lowCelsius)
        )
    }

    private static func conditionDescription(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear:
            return AppLocalization.text("晴")
        case .partlyCloudy, .mostlyCloudy, .cloudy, .haze, .smoky:
            return AppLocalization.text("多云")
        case .drizzle, .rain, .heavyRain, .sunShowers, .freezingDrizzle, .freezingRain:
            return AppLocalization.text("有雨")
        case .snow, .heavySnow, .sunFlurries, .flurries, .sleet, .wintryMix, .blowingSnow, .blizzard:
            return AppLocalization.text("雨雪")
        case .thunderstorms, .scatteredThunderstorms, .isolatedThunderstorms, .strongStorms, .tropicalStorm, .hurricane:
            return AppLocalization.text("雷暴")
        case .foggy:
            return AppLocalization.text("有雾")
        case .windy, .breezy, .blowingDust:
            return AppLocalization.text("有风")
        case .hot:
            return AppLocalization.text("炎热")
        case .frigid:
            return AppLocalization.text("寒冷")
        case .hail:
            return AppLocalization.text("冰雹")
        default:
            return AppLocalization.text("天气变化")
        }
    }

    private static func temperatureBandDescription(highCelsius: Int, lowCelsius: Int) -> String {
        if highCelsius >= 30 {
            return AppLocalization.text("偏热")
        }

        if lowCelsius <= 8 {
            return AppLocalization.text("偏冷")
        }

        return AppLocalization.text("温和")
    }

    private static func temperatureTintColor(highCelsius: Int, lowCelsius: Int) -> UIColor {
        if highCelsius >= 30 {
            return .systemOrange
        }

        if lowCelsius <= 8 {
            return .systemBlue
        }

        return .systemTeal
    }
}

extension CalendarWeatherModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorizationStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            authorizationRequestInFlight = false
            emitDebugTrace("authorization changed status=\(authorizationStatus.rawValue)")
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                requestLocationIfNeeded(forceRefresh: false, trigger: "authorization granted, requesting location")
            } else if authorizationStatus == .denied || authorizationStatus == .restricted {
                emitDebugTrace("authorization rejected after prompt")
                locationRequestInFlight = false
                state = .denied
            } else if authorizationStatus == .notDetermined {
                state = .needsAuthorization
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let location = locations.last else {
                locationRequestInFlight = false
                emitDebugTrace("location manager returned no locations")
                state = .failed(AppLocalization.text("没有拿到当前位置，请稍后重试。"))
                return
            }

            guard locationRequestInFlight else {
                emitDebugTrace("ignoring duplicate location callback")
                return
            }
            locationRequestInFlight = false
            emitDebugTrace("location updated")
            loadWeather(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            locationRequestInFlight = false

            let message: String
            if let error = error as? CLError {
                switch error.code {
                case .denied:
                    state = .denied
                    return
                case .locationUnknown:
                    message = AppLocalization.text("当前位置暂时不可用，请稍后再试。")
                default:
                    message = AppLocalization.text("定位失败，请稍后重试。")
                }
            } else {
                message = AppLocalization.text("定位失败，请稍后重试。")
            }

            logger.error("Failed to resolve location: \(error.localizedDescription, privacy: .public)")
            emitDebugTrace("location manager failed message=\(error.localizedDescription)")
            state = .failed(message)
        }
    }
}
