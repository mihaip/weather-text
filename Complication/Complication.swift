import SwiftUI
import WidgetKit
import WeatherKit
import os

class EntryCache {
    var previousEntry: WeatherEntry?
}

struct Provider: TimelineProvider {
    private let locationFetcher = LocationFetcher()
    private let entryCache = EntryCache()
    private let logger = Logger()

    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, data: .success(goodWeatherData))
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
                    let newEntry = WeatherEntry(date: now, data: .success(data))
                    entryCache.previousEntry = newEntry
                    completion(newEntry)
                } catch {
                    if let previousEntry = entryCache.previousEntry {
                        if now.timeIntervalSince(previousEntry.date) < 24 * 3600 {
                            logger.warning("Got error \(error) when generating timeline entry, using previous value from \(previousEntry.date)")
                            completion(previousEntry)
                            return
                        }
                    }
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

struct ComplicationEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            switch entry.data {
            case .success(let weather):
                WeatherView(weather: weather)
                if Prefs.shared.showFooter {
                    WeatherFooterView(date: entry.date, locationName: weather.locationName)
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
    WeatherEntry(date: .now, data: .success(goodWeatherData))
    WeatherEntry(date: .now, data: .success(mediumWeatherData))
    WeatherEntry(date: .now, data: .success(badWeatherData))
    WeatherEntry(date: .now, data: .failure(NSError(domain: "info.persistent.WeatherText", code: 127)))
}
