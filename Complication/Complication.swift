import SwiftUI
import WidgetKit
import WeatherKit
import os

class EntryCache {
    private let defaults = UserDefaults(suiteName: "group.info.persistent.Weather-Text")
    private let key = "previousWeatherEntry"
    private let maximumAge: TimeInterval = 24 * 60 * 60

    func load(now: Date) -> StoredWeatherEntry? {
        guard let data = defaults?.data(forKey: key),
              let entry = try? JSONDecoder().decode(StoredWeatherEntry.self, from: data),
              now.timeIntervalSince(entry.weatherDate) >= 0,
              now.timeIntervalSince(entry.weatherDate) < maximumAge else {
            return nil
        }
        return entry
    }

    func save(_ entry: StoredWeatherEntry) {
        guard let data = try? JSONEncoder().encode(entry) else {
            return
        }
        defaults?.set(data, forKey: key)
    }
}

struct Provider: TimelineProvider {
    private let locationFetcher = LocationFetcher()
    private let entryCache = EntryCache()
    private let logger = Logger()

    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, weatherDate: .now, isStale: false, data: .success(goodWeatherData))
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> ()) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        locationFetcher.fetch { result in
            Task {
                let now = Date()
                do {
                    let location = try result.get()
                    let data = try await WeatherData.load(location: location, now: now)
                    let newEntry = WeatherEntry(date: now, weatherDate: now, isStale: false, data: .success(data))
                    entryCache.save(StoredWeatherEntry(weatherDate: now, data: data))
                    completion(newEntry)
                } catch {
                    if let previousEntry = entryCache.load(now: now) {
                        logger.warning("Got error \(error) when generating timeline entry, using previous value from \(previousEntry.weatherDate)")
                        completion(WeatherEntry(
                            date: now,
                            weatherDate: previousEntry.weatherDate,
                            isStale: true,
                            data: .success(previousEntry.data)
                        ))
                        return
                    }
                    completion(WeatherEntry(date: now, weatherDate: now, isStale: false, data: .failure(error)))
                }
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        getSnapshot(in: context) { entry in
            let refreshInterval: TimeInterval
            switch (entry.isStale, entry.data) {
            case (false, .success(_)):
                refreshInterval = 3600
            case (true, _), (_, .failure(_)):
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
    let weatherDate: Date
    let isStale: Bool
    let data: Result<WeatherData, Error>
}

struct StoredWeatherEntry: Codable {
    let weatherDate: Date
    let data: WeatherData
}

struct ComplicationEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            switch entry.data {
            case .success(let weather):
                WeatherView(weather: weather)
                if Prefs.shared.showFooter {
                    WeatherFooterView(date: entry.weatherDate, locationName: weather.locationName)
                }
            case .failure(let error):
                WeatherErrorView(error: error)
                if Prefs.shared.showFooter {
                    WeatherFooterView(date: entry.date)
                }
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
        .description("Textual summary of today's weather.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    Complication()
} timeline: {
    WeatherEntry(date: .now, weatherDate: .now, isStale: false, data: .success(goodWeatherData))
    WeatherEntry(date: .now, weatherDate: .now, isStale: false, data: .success(mediumWeatherData))
    WeatherEntry(date: .now, weatherDate: .now, isStale: false, data: .success(badWeatherData))
    WeatherEntry(date: .now, weatherDate: .now, isStale: false, data: .failure(NSError(domain: "info.persistent.WeatherText", code: 127)))
}
