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

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), emoji: "😀")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        locationFetcher.fetch { result in
            Task {
                var output: String
                do {
                    let location = try result.get()
                    output = try await WeatherService.shared.weather(for: location).currentWeather.temperature.debugDescription
                } catch {
                    output = "Error: \(error.localizedDescription)"
                }
                completion(SimpleEntry(date: Date(), emoji: output))
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        getSnapshot(in: context) { entry in
            let timeline = Timeline(entries: [entry], policy: .never)
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let emoji: String
}

struct ComplicationEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text(entry.emoji)
                .font(.caption)
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
    SimpleEntry(date: .now, emoji: "😀")
    SimpleEntry(date: .now, emoji: "🤩")
}
