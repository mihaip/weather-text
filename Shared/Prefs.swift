import Foundation
import WidgetKit

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

    @suiteUserDefault(Prefs.ignoredAlertKey, defaultValue: nil) var ignoredAlertURL: String? {
        willSet { objectWillChange.send() }
    }
    private static let ignoredAlertKey = "ignoredAlert"

    func shouldShow(alert: WeatherAlertData) -> Bool {
        return ignoredAlertURL == nil || alert.detailsURL?.absoluteString != ignoredAlertURL
    }

    func ignore(alert: WeatherAlertData) {
        ignoredAlertURL = alert.detailsURL?.absoluteString
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

