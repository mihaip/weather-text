import Foundation
import WidgetKit

class Prefs: ObservableObject {
    static let shared: Prefs = {
        let instance = Prefs()
        suite?.register(defaults: [
            Prefs.showFooterKey: true,
        ])
        return instance
    }()

    @suiteUserDefault(Prefs.showFooterKey, defaultValue: false) var showFooter: Bool {
        willSet { objectWillChange.send() }
    }
    private static let showFooterKey = "showFooter"
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

