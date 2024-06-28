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
                    let weather = try await WeatherService.shared.weather(for: location)
                    let current = weather.currentWeather
                    let today = weather.dailyForecast[0]

                    var sunEvent : SunEvent?
                    for day in weather.dailyForecast {
                        if let sunrise = day.sun.sunrise, sunrise > now {
                            sunEvent = .sunrise(sunrise)
                            break
                        }
                        if let sunset = day.sun.sunset, sunset > now {
                            sunEvent = .sunset(sunset)
                            break
                        }
                    }

                    let data = WeatherData(
                        currentTemperature: current.temperature,
                        currentSymbol: current.symbolName,
                        currentCondition: current.condition,
                        highTemperature: today.highTemperature,
                        lowTemperature: today.lowTemperature,
                        sunEvent: sunEvent
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
            let refreshDate = entry.date.addingTimeInterval(3600)
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
}

enum SunEvent {
    case sunrise(Date)
    case sunset(Date)
}

struct ComplicationEntryView : View {
    var entry: Provider.Entry

    private let temperatureFormat: Measurement<UnitTemperature>.FormatStyle = .measurement(
        width: .narrow,
        hidesScaleName: true,
        numberFormatStyle: FloatingPointFormatStyle<Double>().precision(.fractionLength(0))
    )

    var body: some View {
        VStack(alignment: .leading) {
            switch entry.data {
            case .success(let weather):
                HStack {
                    Image(systemName: weather.currentSymbol)
                    Text(weather.currentTemperature, format: temperatureFormat)
                    Text(weather.currentCondition.description)
                }
                .font(.headline)
                HStack {
                    Text("High:")
                    Text(weather.highTemperature, format: temperatureFormat)
                    Text("Low:")
                    Text(weather.lowTemperature, format: temperatureFormat)
                }
                .font(.subheadline)
                if let sunEvent = weather.sunEvent {
                    HStack {
                        switch sunEvent {
                        case .sunrise(let date):
                            Text("Sunrise:")
                            Text(date, style: .time)
                        case .sunset(let date):
                            Text("Sunset:")
                            Text(date, style: .time)
                        }
                    }.foregroundStyle(.secondary)
                }
            case .failure(let error):
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
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
    WeatherEntry(date: .now, data: .success(badWeatherData))
    WeatherEntry(date: .now, data: .failure(NSError(domain: "info.persistent.WeatherText", code: 127)))
}

let goodWeatherData = WeatherData(
    currentTemperature: Measurement(value: 62.9, unit: UnitTemperature.fahrenheit),
    currentSymbol: "cloud.sun",
    currentCondition: .partlyCloudy,
    highTemperature: Measurement(value: 78.6, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 48.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunrise(Calendar.current.date(bySetting: .hour, value: 7, of: Date())!)
)

let badWeatherData = WeatherData(
    currentTemperature: Measurement(value: 20.7, unit: UnitTemperature.fahrenheit),
    currentSymbol: "wind.snow",
    currentCondition: .blizzard,
    highTemperature: Measurement(value: 30.7, unit: UnitTemperature.fahrenheit),
    lowTemperature: Measurement(value: 12.2, unit: UnitTemperature.fahrenheit),
    sunEvent: .sunset(Calendar.current.date(bySetting: .hour, value: 17, of: Date())!)
)
