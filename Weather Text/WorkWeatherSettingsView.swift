import CoreLocation
import MapKit
import SwiftUI

struct WorkWeatherSettingsView: View {
    let currentLocation: CLLocation
    @ObservedObject private var prefs = Prefs.shared
    @State private var diagnosticState = WorkWeatherDiagnosticState.loading

    private var settings: WorkWeatherSettings {
        prefs.workWeatherSettings
    }

    var body: some View {
        WorkWeatherSettingsForm(
            currentLocation: currentLocation,
            settings: Binding(
                get: { prefs.workWeatherSettings },
                set: { prefs.workWeatherSettings = $0 }
            ),
            diagnosticState: diagnosticState
        )
        .navigationTitle("Work Weather")
        .task(id: WorkWeatherDiagnosticID(
            location: currentLocation,
            settings: settings
        )) {
            diagnosticState = .loading
            do {
                let diagnostic = try await WorkWeatherDiagnostic.load(
                    currentLocation: currentLocation,
                    settings: settings,
                    now: Date.now
                )
                try Task.checkCancellation()
                diagnosticState = diagnostic.map(WorkWeatherDiagnosticState.loaded) ?? .unavailable
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                diagnosticState = .failed(error)
            }
        }
    }
}

private struct WorkWeatherSettingsForm: View {
    let currentLocation: CLLocation
    @Binding var settings: WorkWeatherSettings
    let diagnosticState: WorkWeatherDiagnosticState

    var body: some View {
        Form {
            Section {
                Text("Show important weather differences at your work location on workday mornings.")
                    .listRowBackground(Color.clear)
            }

            Section {
                Toggle("Work weather", isOn: binding(\.isEnabled))
                    .disabled(settings.location == nil)
                NavigationLink {
                    WorkLocationView(currentLocation: currentLocation)
                } label: {
                    VStack(alignment: .leading) {
                        Text("Work location")
                        Text(settings.location?.name ?? "Not set")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if settings.location != nil {
                    WorkWeatherDiagnosticView(state: diagnosticState)
                }
            }

            Section("Work days") {
                ForEach(workDays, id: \.value) { day in
                    Toggle(day.name, isOn: workDayBinding(day.value))
                }
            }

            Section("Show until") {
                DatePicker(
                    "",
                    selection: timeBinding(\.cutoffMinutes),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<WorkWeatherSettings, T>) -> Binding<T> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { value in
                var updated = settings
                updated[keyPath: keyPath] = value
                settings = updated
            }
        )
    }

    private func workDayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { settings.workDays.contains(weekday) },
            set: { isEnabled in
                var updated = settings
                if isEnabled {
                    updated.workDays.insert(weekday)
                } else {
                    updated.workDays.remove(weekday)
                }
                settings = updated
            }
        )
    }

    private func timeBinding(_ keyPath: WritableKeyPath<WorkWeatherSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = settings[keyPath: keyPath]
                return Calendar.current.date(
                    bySettingHour: minutes / 60,
                    minute: minutes % 60,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                guard let hour = components.hour, let minute = components.minute else {
                    return
                }
                var updated = settings
                updated[keyPath: keyPath] = hour * 60 + minute
                settings = updated
            }
        )
    }
}

private enum WorkWeatherDiagnosticState {
    case loading
    case loaded(WorkWeatherDiagnostic)
    case unavailable
    case failed(Error)
}

private extension WorkWeatherInsight {
    func summary(
        format temperatureFormat: Measurement<UnitTemperature>.FormatStyle,
        currentDailyHigh: Measurement<UnitTemperature>
    ) -> Text {
        var text = Text("High ") + Text(highTemperature, format: temperatureFormat)
        switch reason {
        case .precipitation(let kind, let chance):
            text = Text("\(kind) \(chance, format: .percent.precision(.fractionLength(0))) · High ")
                + Text(highTemperature, format: temperatureFormat)
        case .lowerHigh:
            text = text + Text(" · ") + formatHighDifference(from: currentDailyHigh) + Text(" lower")
        case .higherHigh:
            text = text + Text(" · ") + formatHighDifference(from: currentDailyHigh) + Text(" higher")
        }
        return text
    }
}

private struct WorkWeatherDiagnosticView: View {
    let state: WorkWeatherDiagnosticState

    private let temperatureFormat: Measurement<UnitTemperature>.FormatStyle = .measurement(
        width: .narrow,
        hidesScaleName: true,
        numberFormatStyle: FloatingPointFormatStyle<Double>().precision(.fractionLength(0))
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch state {
            case .loading:
                ProgressView()
            case .loaded(let diagnostic):
                HStack {
                    Image(systemName: diagnostic.currentSymbol)
                    Text(diagnostic.currentTemperature, format: temperatureFormat)
                    Text(diagnostic.currentCondition.description)
                }
                .font(.callout)
                if let insight = diagnostic.insight {
                    DiagnosticStatusRow(symbol: "checkmark.circle.fill") {
                        Text("Different enough today: ")
                            + insight.summary(
                                format: temperatureFormat,
                                currentDailyHigh: diagnostic.currentDailyHigh
                            )
                    }
                    .foregroundStyle(.green)
                } else {
                    DiagnosticStatusRow(symbol: "minus.circle") {
                        Text("Not different enough today")
                    }
                        .foregroundStyle(.secondary)
                }
                visibilityStatus(diagnostic.visibility)
            case .unavailable:
                EmptyView()
            case .failed:
                Label("Couldn’t check work weather", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.yellow)
            }
        }
        .font(.caption)
    }

    @ViewBuilder
    private func visibilityStatus(_ visibility: WorkWeatherVisibility) -> some View {
        switch visibility {
        case .visible:
            DiagnosticStatusRow(symbol: "eye") {
                Text("Currently eligible to show")
            }
                .foregroundStyle(.secondary)
        case .disabled:
            DiagnosticStatusRow(symbol: "eye.slash") {
                Text("Not currently eligible: turned off")
            }
                .foregroundStyle(.secondary)
        case .notWorkDay:
            DiagnosticStatusRow(symbol: "eye.slash") {
                Text("Not currently eligible: not a work day")
            }
                .foregroundStyle(.secondary)
        case .pastCutoff(let cutoff):
            DiagnosticStatusRow(symbol: "eye.slash") {
                Text("Not currently eligible: past ")
                    + Text(cutoff, style: .time)
            }
            .foregroundStyle(.secondary)
        case .nearWork:
            DiagnosticStatusRow(symbol: "eye.slash") {
                Text("Not currently eligible: near work")
            }
                .foregroundStyle(.secondary)
        }
    }
}

private struct DiagnosticStatusRow<Content: View>: View {
    let symbol: String
    let content: Content

    init(symbol: String, @ViewBuilder content: () -> Content) {
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .imageScale(.medium)
                .frame(width: 18, alignment: .center)
            content
        }
    }
}

private struct WorkWeatherDiagnosticID: Hashable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let settings: WorkWeatherSettings

    init(location: CLLocation, settings: WorkWeatherSettings) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        self.settings = settings
    }
}

private let workDays = [
    (value: 2, name: "Monday"),
    (value: 3, name: "Tuesday"),
    (value: 4, name: "Wednesday"),
    (value: 5, name: "Thursday"),
    (value: 6, name: "Friday"),
    (value: 7, name: "Saturday"),
    (value: 1, name: "Sunday"),
]

private struct WorkLocationView: View {
    let currentLocation: CLLocation
    @ObservedObject private var prefs = Prefs.shared
    @State private var isSavingCurrentLocation = false
    @State private var error: Error?

    var body: some View {
        List {
            Button("Use Current Location", systemImage: "location.fill") {
                isSavingCurrentLocation = true
                Task {
                    do {
                        let name = try await locationName(for: currentLocation)
                        save(location: currentLocation, name: name)
                    } catch {
                        self.error = error
                    }
                    isSavingCurrentLocation = false
                }
            }
            .disabled(isSavingCurrentLocation)

            NavigationLink {
                WorkLocationSearchView()
            } label: {
                Label("Search for a Place", systemImage: "magnifyingglass")
            }

            if let location = prefs.workWeatherSettings.location {
                Section("Current") {
                    Text(location.name)
                    Button("Remove Work Location", role: .destructive) {
                        var settings = prefs.workWeatherSettings
                        settings.location = nil
                        settings.isEnabled = false
                        prefs.workWeatherSettings = settings
                    }
                }
            }

            if let error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .navigationTitle("Work Location")
    }

    private func save(location: CLLocation, name: String) {
        var settings = prefs.workWeatherSettings
        settings.location = SavedLocation(
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        settings.isEnabled = true
        prefs.workWeatherSettings = settings
    }
}

private struct WorkLocationSearchView: View {
    @StateObject private var search = LocationSearch()
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var prefs = Prefs.shared
    @State private var error: Error?

    var body: some View {
        List {
            TextField("Place or address", text: $search.query)
            ForEach(search.results, id: \.self) { result in
                Button {
                    Task {
                        do {
                            let request = MKLocalSearch.Request(completion: result)
                            let response = try await MKLocalSearch(request: request).start()
                            guard let item = response.mapItems.first else {
                                return
                            }
                            var settings = prefs.workWeatherSettings
                            settings.location = SavedLocation(
                                name: item.name ?? result.title,
                                latitude: item.placemark.coordinate.latitude,
                                longitude: item.placemark.coordinate.longitude
                            )
                            settings.isEnabled = true
                            prefs.workWeatherSettings = settings
                            dismiss()
                        } catch {
                            self.error = error
                        }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(result.title)
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .navigationTitle("Search")
    }
}

private final class LocationSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            completer.queryFragment = query
        }
    }
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

private func locationName(for location: CLLocation) async throws -> String {
    let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
    guard let placemark = placemarks.first else {
        return "Work"
    }
    if let name = placemark.name {
        return name
    }
    if let city = placemark.locality {
        return city
    }
    return "Work"
}

#Preview {
    @Previewable @State var settings = WorkWeatherSettings(
        isEnabled: true,
        location: SavedLocation(
            name: "San Francisco, CA",
            latitude: 37.7749,
            longitude: -122.4194
        ),
        workDays: [2, 3, 4, 5, 6],
        cutoffMinutes: 10 * 60
    )

    NavigationStack {
        WorkWeatherSettingsForm(
            currentLocation: previewLocation,
            settings: $settings,
            diagnosticState: .loaded(WorkWeatherDiagnostic(
                currentSymbol: "cloud.sun",
                currentTemperature: Measurement(value: 70, unit: UnitTemperature.fahrenheit),
                currentDailyHigh: Measurement(value: 84, unit: UnitTemperature.fahrenheit),
                currentCondition: .partlyCloudy,
                insight: WorkWeatherInsight(
                    symbol: "cloud.fill",
                    highTemperature: Measurement(value: 70, unit: UnitTemperature.fahrenheit),
                    reason: .lowerHigh,
                    expiresAt: Calendar.current.date(
                        bySettingHour: 10,
                        minute: 0,
                        second: 0,
                        of: Date()
                    )!
                ),
                visibility: .notWorkDay
            ))
        )
        .navigationTitle("Work Weather")
    }
}
