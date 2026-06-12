import CoreLocation
import Foundation
import SwiftUI
import WeatherKit

struct WeatherData: Codable {
    let locationName: String?
    let currentTemperature: Measurement<UnitTemperature>
    let currentSymbol: String
    let currentCondition: WeatherCondition

    let highTemperature: Measurement<UnitTemperature>
    let lowTemperature: Measurement<UnitTemperature>

    let sunEvent: SunEvent?
    let alert: WeatherAlertData?
    let workWeather: WorkWeatherInsight?

    static func load(
        location: CLLocation,
        now: Date,
        workSettings: WorkWeatherSettings = Prefs.shared.workWeatherSettings
    ) async throws -> WeatherData {
        let (current, daily, alerts) = try await WeatherService.shared.weather(
            for: location,
            including: .current,
            .daily,
            .alerts
        )
        guard let today = daily.first else {
            throw WeatherDataError.missingDailyForecast
        }

        var sunEvent : SunEvent?
        for day in daily {
            if let sunrise = day.sun.sunrise, sunrise > now {
                sunEvent = .sunrise(sunrise)
                break
            }
            if let sunset = day.sun.sunset, sunset > now {
                sunEvent = .sunset(sunset)
                break
            }
        }

        var alert: WeatherAlertData?
        if let alerts {
            for a in alerts {
                let severity: WeatherAlertSeverity
                switch a.severity {
                case .minor, .moderate:
                    continue // Ignored if not that important
                case .severe:
                    severity = .severe
                case .extreme:
                    severity = .extreme
                case .unknown:
                    severity = .unknown
                @unknown default:
                    severity = .unknown
                }
                alert = WeatherAlertData(detailsURL: a.detailsURL, severity: severity, source: a.source, summary: a.summary)
            }
        }

        var locationName: String?
        let geocoder = CLGeocoder()
        do {
            let result = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = result.first {
                locationName = placemark.name
                if placemark.isoCountryCode == "US" {
                    if let city = placemark.locality, let state = placemark.administrativeArea {
                        locationName = "\(city), \(state)"
                    }
                } else {
                    if let city = placemark.locality, let country = placemark.country {
                        locationName = "\(city), \(country)"
                    }
                }
            }
        } catch {
            // Geolocation is not load bearing
            print("Cannot geocode location: \(error)")
        }

        let workWeather: WorkWeatherInsight?
        do {
            workWeather = try await WorkWeatherInsight.load(
                request: WorkWeatherRequest.make(
                    currentLocation: location,
                    settings: workSettings,
                    now: now
                ),
                currentDailyHigh: today.highTemperature
            )
        } catch {
            // Work weather is supplementary and should not prevent current
            // location weather from loading.
            print("Cannot load work weather: \(error)")
            workWeather = nil
        }

        return WeatherData(
            locationName: locationName,
            currentTemperature: current.temperature,
            currentSymbol: current.symbolName,
            currentCondition: current.condition,
            highTemperature: today.highTemperature,
            lowTemperature: today.lowTemperature,
            sunEvent: sunEvent,
            alert: alert,
            workWeather: workWeather
        )

    }
}

private struct WorkWeatherRequest {
    let workLocation: CLLocation
    let cutoff: Date

    static func make(
        currentLocation: CLLocation,
        settings: WorkWeatherSettings,
        now: Date
    ) -> WorkWeatherRequest? {
        guard case .visible = WorkWeatherVisibility.evaluate(
            currentLocation: currentLocation,
            settings: settings,
            now: now
        ) else {
            return nil
        }
        return makeForToday(settings: settings, now: now)
    }

    static func makeForToday(settings: WorkWeatherSettings, now: Date) -> WorkWeatherRequest? {
        guard let savedWorkLocation = settings.location,
              let cutoff = Calendar.current.date(
                  bySettingHour: settings.cutoffMinutes / 60,
                  minute: settings.cutoffMinutes % 60,
                  second: 0,
                  of: now
              ) else {
            return nil
        }
        return WorkWeatherRequest(
            workLocation: CLLocation(
                latitude: savedWorkLocation.latitude,
                longitude: savedWorkLocation.longitude
            ),
            cutoff: cutoff
        )
    }
}

enum WorkWeatherVisibility {
    case visible
    case disabled
    case notWorkDay
    case pastCutoff(Date)
    case nearWork

    static func evaluate(
        currentLocation: CLLocation,
        settings: WorkWeatherSettings,
        now: Date
    ) -> WorkWeatherVisibility {
        guard settings.isEnabled else {
            return .disabled
        }
        guard settings.workDays.contains(Calendar.current.component(.weekday, from: now)) else {
            return .notWorkDay
        }
        guard let request = WorkWeatherRequest.makeForToday(settings: settings, now: now) else {
            return .disabled
        }
        guard now < request.cutoff else {
            return .pastCutoff(request.cutoff)
        }
        let proximityThreshold = 5 * 1_609.344 + max(0, currentLocation.horizontalAccuracy)
        guard currentLocation.distance(from: request.workLocation) > proximityThreshold else {
            return .nearWork
        }
        return .visible
    }
}

struct WorkWeatherInsight: Codable {
    let symbol: String
    let highTemperature: Measurement<UnitTemperature>
    let reason: WorkWeatherReason
    let expiresAt: Date

    fileprivate static func load(
        request: WorkWeatherRequest?,
        currentDailyHigh: Measurement<UnitTemperature>
    ) async throws -> WorkWeatherInsight? {
        guard let request else {
            return nil
        }
        let workDays = try await WeatherService.shared.weather(
            for: request.workLocation,
            including: .daily
        )
        return make(
            request: request,
            currentDailyHigh: currentDailyHigh,
            workDays: workDays
        )
    }

    fileprivate static func make(
        request: WorkWeatherRequest,
        currentDailyHigh: Measurement<UnitTemperature>,
        workDays: Forecast<DayWeather>
    ) -> WorkWeatherInsight? {
        guard let workDay = workDays.first else {
            return nil
        }

        let reason: WorkWeatherReason?
        let highDifference = workDay.highTemperature.converted(to: .fahrenheit).value
            - currentDailyHigh.converted(to: .fahrenheit).value

        if workDay.precipitation != .none && workDay.precipitationChance >= 0.3 {
            reason = .precipitation(
                kind: workDay.precipitation.description.lowercased(),
                chance: workDay.precipitationChance
            )
        } else if highDifference <= -10 {
            reason = .lowerHigh(degrees: abs(highDifference))
        } else if highDifference >= 10 {
            reason = .higherHigh(degrees: highDifference)
        } else {
            reason = nil
        }

        guard let reason else {
            return nil
        }
        return WorkWeatherInsight(
            symbol: workDay.symbolName,
            highTemperature: workDay.highTemperature,
            reason: reason,
            expiresAt: request.cutoff
        )
    }
}

struct WorkWeatherDiagnostic {
    let currentSymbol: String
    let currentTemperature: Measurement<UnitTemperature>
    let currentCondition: WeatherCondition
    let insight: WorkWeatherInsight?
    let visibility: WorkWeatherVisibility

    static func load(
        currentLocation: CLLocation,
        settings: WorkWeatherSettings,
        now: Date
    ) async throws -> WorkWeatherDiagnostic? {
        guard let request = WorkWeatherRequest.makeForToday(settings: settings, now: now) else {
            return nil
        }

        let visibility = WorkWeatherVisibility.evaluate(
            currentLocation: currentLocation,
            settings: settings,
            now: now
        )

        async let currentDays = WeatherService.shared.weather(
            for: currentLocation,
            including: .daily
        )
        async let workForecast = WeatherService.shared.weather(
            for: request.workLocation,
            including: .current,
            .daily
        )
        let (currentDaysResult, (workCurrent, workDays)) =
            try await (currentDays, workForecast)
        guard let currentDay = currentDaysResult.first else {
            throw WeatherDataError.missingDailyForecast
        }

        return WorkWeatherDiagnostic(
            currentSymbol: workCurrent.symbolName,
            currentTemperature: workCurrent.temperature,
            currentCondition: workCurrent.condition,
            insight: WorkWeatherInsight.make(
                request: request,
                currentDailyHigh: currentDay.highTemperature,
                workDays: workDays
            ),
            visibility: visibility
        )
    }
}

enum WorkWeatherReason: Codable {
    case precipitation(kind: String, chance: Double)
    case lowerHigh(degrees: Double)
    case higherHigh(degrees: Double)
}

struct WeatherAlertData: Codable {
    let detailsURL: URL?
    let severity: WeatherAlertSeverity
    let source: String
    let summary: String

    // WeatherKit's Swift API does not expose the REST alert ID or alert expiration time.
    var dismissalIdentifier: String {
        return [source, summary]
            .map {
                $0.split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
                    .lowercased()
            }
            .joined(separator: "|")
    }
}

enum WeatherAlertSeverity: Codable {
    case severe
    case extreme
    case unknown

    var symbol: String {
        switch self {
        case .severe:
            return "exclamationmark.circle.fill"
        case .extreme:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .severe:
            return Color.yellow
        case .extreme:
            return Color.red
        case .unknown:
            return Color.purple
        }
    }
}

enum SunEvent: Codable {
    case sunrise(Date)
    case sunset(Date)
}

let goodWeatherData = WeatherData(
    locationName: previewLocationName,
    currentTemperature: Measurement(value: 62.9, unit: UnitTemperature.fahrenheit),
    currentSymbol: "cloud.sun",
    currentCondition: .partlyCloudy,
    highTemperature: Measurement(value: 78.6, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 48.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunrise(Calendar.current.date(bySetting: .hour, value: 7, of: Date())!),
    alert: nil,
    workWeather: WorkWeatherInsight(
        symbol: "cloud.fill",
        highTemperature: Measurement(value: 63, unit: UnitTemperature.fahrenheit),
        reason: .lowerHigh(degrees: 15),
        expiresAt: Date().addingTimeInterval(3600)
    )
)

let mediumWeatherData = WeatherData(
    locationName: previewLocationName,
    currentTemperature: Measurement(value: 52.9, unit: UnitTemperature.fahrenheit),
    currentSymbol: "cloud.sun",
    currentCondition: .mostlyCloudy,
    highTemperature: Measurement(value: 55.6, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 41.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunrise(Calendar.current.date(bySetting: .hour, value: 7, of: Date())!),
    alert: nil,
    workWeather: nil
)

let badWeatherData = WeatherData(
    locationName: previewLocationName,
    currentTemperature: Measurement(value: 20.7, unit: UnitTemperature.fahrenheit),
    currentSymbol: "wind.snow",
    currentCondition: .blizzard,
    highTemperature: Measurement(value: 30.7, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 12.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunset(Calendar.current.date(bySetting: .hour, value: 17, of: Date())!),
    alert: WeatherAlertData(detailsURL: URL(string: "https://galileo.com")!, severity: .extreme, source: "National Weather Service", summary: "Thunderbolt and lightning, very very frightening"),
    workWeather: nil
)

let previewLocation = CLLocation(latitude: 37.3230, longitude: 122.0322)
let previewLocationName = "Cupertino, CA"

enum WeatherDataError: LocalizedError {
    case missingDailyForecast

    var errorDescription: String? {
        "No daily forecast was returned."
    }
}
