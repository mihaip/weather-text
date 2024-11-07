import CoreLocation
import Foundation
import SwiftUI
import WeatherKit

struct WeatherData {
    let location: CLLocation
    let locationName: String?
    let currentTemperature: Measurement<UnitTemperature>
    let currentSymbol: String
    let currentCondition: WeatherCondition

    let highTemperature: Measurement<UnitTemperature>
    let lowTemperature: Measurement<UnitTemperature>

    let sunEvent: SunEvent?
    let alert: WeatherAlertData?

    static func load(location: CLLocation, now: Date) async throws -> WeatherData {
        let (current, daily, alerts) = try await WeatherService.shared.weather(for: location, including: .current, .daily, .alerts)
        let today = daily[0]

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
                // Happens too often, not actionable.
                if a.summary == "Red Flag Warning" {
                    continue
                }
                switch a.severity {
                case .minor, .moderate:
                    // Ignored if not that important
                    break
                case .severe:
                    alert = WeatherAlertData(severity: .severe, summary: a.summary)
                case .extreme:
                    alert = WeatherAlertData(severity: .extreme, summary: a.summary)
                case .unknown:
                    alert = WeatherAlertData(severity: .unknown, summary: a.summary)
                @unknown default:
                    alert = WeatherAlertData(severity: .unknown, summary: a.summary)
                }
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

        return WeatherData(
            location: location,
            locationName: locationName,
            currentTemperature: current.temperature,
            currentSymbol: current.symbolName,
            currentCondition: current.condition,
            highTemperature: today.highTemperature,
            lowTemperature: today.lowTemperature,
            sunEvent: sunEvent,
            alert: alert
        )

    }
}

struct WeatherAlertData {
    let severity: WeatherAlertSeverity
    let summary: String
}

enum WeatherAlertSeverity {
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

enum SunEvent {
    case sunrise(Date)
    case sunset(Date)
}

let goodWeatherData = WeatherData(
    location: previewLocation,
    locationName: previewLocationName,
    currentTemperature: Measurement(value: 62.9, unit: UnitTemperature.fahrenheit),
    currentSymbol: "cloud.sun",
    currentCondition: .partlyCloudy,
    highTemperature: Measurement(value: 78.6, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 48.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunrise(Calendar.current.date(bySetting: .hour, value: 7, of: Date())!),
    alert: nil
)

let mediumWeatherData = WeatherData(
    location: previewLocation,
    locationName: previewLocationName,
    currentTemperature: Measurement(value: 52.9, unit: UnitTemperature.fahrenheit),
    currentSymbol: "cloud.sun",
    currentCondition: .mostlyCloudy,
    highTemperature: Measurement(value: 55.6, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 41.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunrise(Calendar.current.date(bySetting: .hour, value: 7, of: Date())!),
    alert: nil
)

let badWeatherData = WeatherData(
    location: previewLocation,
    locationName: previewLocationName,
    currentTemperature: Measurement(value: 20.7, unit: UnitTemperature.fahrenheit),
    currentSymbol: "wind.snow",
    currentCondition: .blizzard,
    highTemperature: Measurement(value: 30.7, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 12.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunset(Calendar.current.date(bySetting: .hour, value: 17, of: Date())!),
    alert: WeatherAlertData(severity: .extreme, summary: "Thunderbolt and lightning, very very frightening")
)

let previewLocation = CLLocation(latitude: 37.3230, longitude: 122.0322)
let previewLocationName = "Cupertino, CA"
