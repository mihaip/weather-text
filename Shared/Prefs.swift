import Foundation
import WidgetKit

class Prefs: ObservableObject {
    static let shared: Prefs = {
        let instance = Prefs()
        Prefs.suite?.register(defaults: [
            Prefs.showFooterKey: true,
        ])
        return instance
    }()

    private static let suite = UserDefaults(suiteName:"group.info.persistent.Weather-Text")

    @Published var showFooter: Bool = Prefs.suite?.bool(forKey: Prefs.showFooterKey) ?? true {
        didSet { Prefs.suite?.set(self.showFooter, forKey: Prefs.showFooterKey) }
    }
    private static let showFooterKey = "showFooter"
}

