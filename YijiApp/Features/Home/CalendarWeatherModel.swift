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
        "最高 \(highTemperatureText) · 最低 \(lowTemperatureText)"
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
    private let debugFileURL: URL?

    private var refreshTask: Task<Void, Never>?
    private var lastRefreshDate: Date?
    private var authorizationRequestInFlight = false
    private var locationRequestInFlight = false
    private var weatherRequestRevision = 0

    init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        locationManager: CLLocationManager = CLLocationManager(),
        weatherService: WeatherService = WeatherService()
    ) {
        self.calendar = calendar
        self.locationManager = locationManager
        self.weatherService = weatherService
        self.debugFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("calendar-weather-debug.txt")
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
            return "开启定位后，月历会显示未来 10 天的天气提示。"
        case .loading:
            return "正在获取未来 10 天的天气。"
        case .ready:
            return "天气图标表示天气，颜色表示冷热；超过未来 10 天的日期会留空。"
        case .denied:
            return "定位未开启，月历天气不会显示。"
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
            return "获取天气"
        case .ready:
            return "刷新"
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
            state = .loading
            locationRequestInFlight = true
            emitDebugTrace("requesting location for weather refresh")
            locationManager.requestLocation()
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

    private func loadWeather(for location: CLLocation) {
        refreshTask?.cancel()
        weatherRequestRevision += 1
        let revision = weatherRequestRevision
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                emitDebugTrace(
                    "loading weather lat=\(location.coordinate.latitude) lon=\(location.coordinate.longitude)"
                )
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
            return "WeatherKit 认证失败，请确认开发者后台的 WeatherKit 能力和描述文件已生效。"
        }

        return "天气暂时不可用：\(fallbackDescription)"
    }

    private func debugErrorDescription(for error: Error) -> String {
        let nsError = error as NSError
        let localizedDescription = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawDescription = String(describing: error).trimmingCharacters(in: .whitespacesAndNewlines)
        let description = localizedDescription.isEmpty ? rawDescription : localizedDescription
        return description.replacingOccurrences(of: "\n", with: " ")
    }

    private func emitDebugTrace(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        print("[CalendarWeather] \(message)")
        appendDebugFileLine(message)
    }

    private func appendDebugFileLine(_ message: String) {
        guard let debugFileURL else { return }
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: debugFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: debugFileURL) {
                    defer { try? handle.close() }
                    do {
                        try handle.seekToEnd()
                        try handle.write(contentsOf: data)
                    } catch {
                        logger.error("Failed to append weather debug file: \(error.localizedDescription, privacy: .public)")
                    }
                }
            } else {
                do {
                    try data.write(to: debugFileURL, options: .atomic)
                } catch {
                    logger.error("Failed to create weather debug file: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
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
            return "晴"
        case .partlyCloudy, .mostlyCloudy, .cloudy, .haze, .smoky:
            return "多云"
        case .drizzle, .rain, .heavyRain, .sunShowers, .freezingDrizzle, .freezingRain:
            return "有雨"
        case .snow, .heavySnow, .sunFlurries, .flurries, .sleet, .wintryMix, .blowingSnow, .blizzard:
            return "雨雪"
        case .thunderstorms, .scatteredThunderstorms, .isolatedThunderstorms, .strongStorms, .tropicalStorm, .hurricane:
            return "雷暴"
        case .foggy:
            return "有雾"
        case .windy, .breezy, .blowingDust:
            return "有风"
        case .hot:
            return "炎热"
        case .frigid:
            return "寒冷"
        case .hail:
            return "冰雹"
        default:
            return "天气变化"
        }
    }

    private static func temperatureBandDescription(highCelsius: Int, lowCelsius: Int) -> String {
        if highCelsius >= 30 {
            return "偏热"
        }

        if lowCelsius <= 8 {
            return "偏冷"
        }

        return "温和"
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
                guard !locationRequestInFlight else {
                    emitDebugTrace("authorization callback ignored because location request is already in flight")
                    return
                }
                state = .loading
                locationRequestInFlight = true
                emitDebugTrace("authorization granted, requesting location")
                locationManager.requestLocation()
            } else if authorizationStatus == .denied || authorizationStatus == .restricted {
                emitDebugTrace("authorization rejected after prompt")
                locationRequestInFlight = false
                state = .denied
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let location = locations.last else {
                locationRequestInFlight = false
                emitDebugTrace("location manager returned no locations")
                state = .failed("没有拿到当前位置，请稍后重试。")
                return
            }

            guard locationRequestInFlight else {
                emitDebugTrace("ignoring duplicate location callback")
                return
            }
            locationRequestInFlight = false
            emitDebugTrace(
                "location updated lat=\(location.coordinate.latitude) lon=\(location.coordinate.longitude)"
            )
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
                    message = "当前位置暂时不可用，请稍后再试。"
                default:
                    message = "定位失败，请稍后重试。"
                }
            } else {
                message = "定位失败，请稍后重试。"
            }

            logger.error("Failed to resolve location: \(error.localizedDescription, privacy: .public)")
            emitDebugTrace("location manager failed message=\(error.localizedDescription)")
            state = .failed(message)
        }
    }
}
