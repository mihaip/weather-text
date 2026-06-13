import Foundation
import WidgetKit

struct SavedLocation: Codable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double
}

struct WorkWeatherSettings: Codable, Hashable {
    var isEnabled = false
    var location: SavedLocation?
    var workDays: Set<Int> = [2, 3, 4, 5, 6]
    var cutoffMinutes = 10 * 60
}

class Prefs: ObservableObject {
    static let shared: Prefs = {
        let instance = Prefs()
        suite?.register(defaults: [
            Prefs.showFooterKey: false,
        ])
        return instance
    }()

    @suiteUserDefault(Prefs.showFooterKey, defaultValue: false) var showFooter: Bool {
        willSet { objectWillChange.send() }
    }
    private static let showFooterKey = "showFooter"

    var workWeatherSettings: WorkWeatherSettings {
        get {
            guard let data = suite?.data(forKey: Prefs.workWeatherSettingsKey),
                  let settings = try? JSONDecoder().decode(WorkWeatherSettings.self, from: data) else {
                return WorkWeatherSettings()
            }
            return settings
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                return
            }
            objectWillChange.send()
            suite?.set(data, forKey: Prefs.workWeatherSettingsKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    private static let workWeatherSettingsKey = "workWeatherSettings"

    @suiteUserDefault(Prefs.ignoredAlertsKey, defaultValue: [:]) var ignoredAlerts: [String: Double] {
        willSet { objectWillChange.send() }
    }
    private static let ignoredAlertsKey = "ignoredAlerts"
    private static let ignoredAlertLifetime: TimeInterval = 24 * 60 * 60

    func shouldShow(alert: WeatherAlertData, now: Date = Date()) -> Bool {
        guard let ignoredAt = ignoredAlerts[alert.dismissalIdentifier] else {
            return true
        }
        return now.timeIntervalSince1970 - ignoredAt >= Prefs.ignoredAlertLifetime
    }

    func ignore(alert: WeatherAlertData, now: Date = Date()) {
        let cutoff = now.timeIntervalSince1970 - Prefs.ignoredAlertLifetime
        ignoredAlerts = ignoredAlerts.filter { $0.value > cutoff }
            .merging([alert.dismissalIdentifier: now.timeIntervalSince1970]) { _, new in new }
    }
}

fileprivate let suite = UserDefaults(suiteName:"group.info.persistent.Weather-Text")

@propertyWrapper
struct suiteUserDefault<T> {
    let key: String
    let defaultValue: T

    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            suite?.object(forKey: key) as? T ?? defaultValue
        }
        set {
            suite?.set(newValue, forKey: key)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
