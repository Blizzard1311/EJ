import CoreLocation
import SwiftUI
import WeatherKit

@main
struct WeatherKitProbeApp: App {
    var body: some Scene {
        WindowGroup {
            WeatherKitProbeView()
        }
    }
}

private struct WeatherKitProbeView: View {
    @StateObject private var model = WeatherKitProbeModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WeatherKit Probe")
                .font(.title.bold())

            Text(model.status)
                .font(.body)
                .textSelection(.enabled)

            if let details = model.details {
                Text(details)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Button("Run Probe") {
                model.start()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isRunning)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            model.start()
        }
    }
}

@MainActor
private final class WeatherKitProbeModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status = "Ready"
    @Published var details: String?
    @Published var isRunning = false

    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService()
    private let debugFileURL: URL?

    override init() {
        self.debugFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("weatherkit-probe-debug.txt")
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func start() {
        isRunning = true
        details = nil
        trace("start authorizationStatus=\(locationManager.authorizationStatus.rawValue)")

        switch locationManager.authorizationStatus {
        case .notDetermined:
            status = "Requesting location permission"
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocation()
        case .denied, .restricted:
            status = "Location permission denied"
            isRunning = false
            trace("location permission denied")
        @unknown default:
            status = "Unknown location authorization"
            isRunning = false
            trace("unknown authorization status")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorizationStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            trace("authorization changed status=\(authorizationStatus.rawValue)")

            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                requestLocation()
            } else if authorizationStatus == .denied || authorizationStatus == .restricted {
                status = "Location permission denied"
                isRunning = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self, let location = locations.last else { return }
            await loadWeather(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            status = "Location failed"
            details = describe(error)
            isRunning = false
            trace("location failed \(describe(error))")
        }
    }

    private func requestLocation() {
        status = "Requesting location"
        trace("requesting location")
        locationManager.requestLocation()
    }

    private func loadWeather(for location: CLLocation) async {
        status = "Requesting WeatherKit"
        trace("location lat=\(location.coordinate.latitude) lon=\(location.coordinate.longitude)")

        do {
            let weather = try await weatherService.weather(for: location)
            let forecastCount = weather.dailyForecast.forecast.count
            let current = weather.currentWeather
            let message = "success condition=\(current.condition.description) symbol=\(current.symbolName) forecastCount=\(forecastCount)"
            status = "WeatherKit success"
            details = message
            trace(message)
        } catch {
            let message = describe(error)
            status = "WeatherKit failed"
            details = message
            trace("weather failed domain=\((error as NSError).domain) code=\((error as NSError).code) details=\(message)")
        }

        isRunning = false
    }

    private func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
    }

    private func trace(_ message: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        print("[WeatherKitProbe] \(message)")

        guard let debugFileURL, let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: debugFileURL.path),
           let handle = try? FileHandle(forWritingTo: debugFileURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: debugFileURL, options: .atomic)
        }
    }
}
