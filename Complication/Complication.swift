import SwiftUI
import WidgetKit
import WeatherKit

enum LocationFetcherError : Error {
    case restricted
    case denied
    case unknownAuthorizationStatus(CLAuthorizationStatus)
}

private class LocationFetcher : NSObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager
    private var completion: ((Result<CLLocation, Error>) -> ())?

    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.delegate = self
    }

    func fetch (_ completion: @escaping (Result<CLLocation, Error>) -> Void) {
        self.completion = completion
        if let location = locationManager.location {
            completion(.success(location))
        } else {
            locationManager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let completion else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .restricted:
            completion(.failure(LocationFetcherError.restricted))
        case .denied:
            completion(.failure(LocationFetcherError.denied))
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        @unknown default:
            completion(.failure(LocationFetcherError.unknownAuthorizationStatus(manager.authorizationStatus)))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let completion else { return }
        completion(.success(locations.last!))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let completion else { return }
        completion(.failure(error))
    }
}


struct Provider: TimelineProvider {
    private let locationFetcher = LocationFetcher()

    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, data: .success(goodWeatherData))
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> ()) {
        locationFetcher.fetch { result in
            Task {
                let now = Date()
                do {
                    let location = try result.get()
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


                    let data = WeatherData(
                        currentTemperature: current.temperature,
                        currentSymbol: current.symbolName,
                        currentCondition: current.condition,
                        highTemperature: today.highTemperature,
                        lowTemperature: today.lowTemperature,
                        sunEvent: sunEvent,
                        alert: alert
                    )
                    completion(WeatherEntry(date: now, data: .success(data)))
                } catch {
                    completion(WeatherEntry(date: now, data: .failure(error)))
                }
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        getSnapshot(in: context) { entry in
            let refreshInterval: TimeInterval
            switch entry.data {
            case .success(_):
                refreshInterval = 3600
            case .failure(_):
                refreshInterval = 300
            }
            let refreshDate = entry.date.addingTimeInterval(refreshInterval)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}


struct WeatherEntry: TimelineEntry {
    let date: Date
    let data: Result<WeatherData, Error>
}

struct WeatherData {
    let currentTemperature: Measurement<UnitTemperature>
    let currentSymbol: String
    let currentCondition: WeatherCondition

    let highTemperature: Measurement<UnitTemperature>
    let lowTemperature: Measurement<UnitTemperature>

    let sunEvent: SunEvent?
    let alert: WeatherAlertData?
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

struct ComplicationEntryView : View {
    var entry: Provider.Entry
    @ScaledMetric var mediumSpacing = 6
    @ScaledMetric var smallSpacing = 2

    private let temperatureFormat: Measurement<UnitTemperature>.FormatStyle = .measurement(
        width: .narrow,
        hidesScaleName: true,
        numberFormatStyle: FloatingPointFormatStyle<Double>().precision(.fractionLength(0))
    )

    var body: some View {
        VStack(alignment: .leading) {
            switch entry.data {
            case .success(let weather):
                HStack(spacing: mediumSpacing) {
                    Image(systemName: weather.currentSymbol)
                    Text(weather.currentTemperature, format: temperatureFormat)
                    Text(weather.currentCondition.description)
                }
                .font(.headline)
                .scaledToFill()
                .minimumScaleFactor(0.8)
                HStack(spacing: 0) {
                    Text("Low:")
                        .padding([.trailing], smallSpacing)
                    Text(weather.lowTemperature, format: temperatureFormat)
                        .padding([.trailing], mediumSpacing)
                    Text("High:")
                        .padding([.trailing], smallSpacing)
                    Text(weather.highTemperature, format: temperatureFormat)
                }
                .font(.subheadline)
                .scaledToFill()
                .minimumScaleFactor(0.8)
                if let alert = weather.alert {
                    HStack(spacing: mediumSpacing) {
                        Image(systemName: alert.severity.symbol)
                        Text(alert.summary)
                    }
                    .font(.callout)
                    .foregroundStyle(alert.severity.color)
                } else if let sunEvent = weather.sunEvent {
                    HStack(spacing: 0) {
                        switch sunEvent {
                        case .sunrise(let date):
                            Text("Sunrise:")
                                .padding([.trailing], smallSpacing)
                            Text(date, style: .time)
                        case .sunset(let date):
                            Text("Sunset:")
                                .padding([.trailing], smallSpacing)
                            Text(date, style: .time)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .scaledToFill()
                    .minimumScaleFactor(0.8)
                }
            case .failure(let error):
                HStack(spacing: mediumSpacing) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Unavailable")
                }
                    .foregroundStyle(.red)
                    .font(.headline)
                    .scaledToFill()
                    .minimumScaleFactor(0.8)
                Text(error.localizedDescription)
                    .font(.caption)
            }
            HStack(spacing: 0) {
                Spacer()
                Text("@")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@main
struct Complication: Widget {
    let kind: String = "Complication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weather Summary")
        .description("One-sentence summary of today's weather.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    Complication()
} timeline: {
    WeatherEntry(date: .now, data: .success(goodWeatherData))
    WeatherEntry(date: .now, data: .success(mediumWeatherData))
    WeatherEntry(date: .now, data: .success(badWeatherData))
    WeatherEntry(date: .now, data: .failure(NSError(domain: "info.persistent.WeatherText", code: 127)))
}

let goodWeatherData = WeatherData(
    currentTemperature: Measurement(value: 62.9, unit: UnitTemperature.fahrenheit),
    currentSymbol: "cloud.sun",
    currentCondition: .partlyCloudy,
    highTemperature: Measurement(value: 78.6, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 48.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunrise(Calendar.current.date(bySetting: .hour, value: 7, of: Date())!),
    alert: nil
)

let mediumWeatherData = WeatherData(
    currentTemperature: Measurement(value: 52.9, unit: UnitTemperature.fahrenheit),
    currentSymbol: "cloud.sun",
    currentCondition: .mostlyCloudy,
    highTemperature: Measurement(value: 55.6, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 41.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunrise(Calendar.current.date(bySetting: .hour, value: 7, of: Date())!),
    alert: nil
)

let badWeatherData = WeatherData(
    currentTemperature: Measurement(value: 20.7, unit: UnitTemperature.fahrenheit),
    currentSymbol: "wind.snow",
    currentCondition: .blizzard,
    highTemperature: Measurement(value: 30.7, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 12.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunset(Calendar.current.date(bySetting: .hour, value: 17, of: Date())!),
    alert: WeatherAlertData(severity: .extreme, summary: "Thunderbolt and lightning, very very frightening")
)
