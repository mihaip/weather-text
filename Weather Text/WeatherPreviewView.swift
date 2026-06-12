import CoreLocation
import SwiftUI

struct WeatherPreviewView: View {
    var location: CLLocation
    let now: Date
    var locationRefreshError: Error? = nil
    var retryLocation: (() -> Void)? = nil

    enum WeatherState {
      case loading
      case loaded(WeatherData, date: Date, refreshError: Error?)
      case failed(Error)
    }
    @State private var state = WeatherState.loading
    @State private var retryID = 0
    @ObservedObject var prefs = Prefs.shared

    var body: some View {
        Form {
            Section {
                Text("Weather widget and complication ready to be added.")
                    .listRowBackground(Color.clear)
            }

            Section("Preview") {
                VStack(alignment: .leading) {
                    switch state {
                    case .loading:
                        // Keep the loading preview the same height as the loaded content.
                        ZStack {
                            VStack(alignment: .leading) {
                                WeatherView(weather: goodWeatherData)
                                if Prefs.shared.showFooter {
                                    WeatherFooterView(
                                        date: Date.now,
                                        locationName: goodWeatherData.locationName
                                    )
                                }
                            }
                            .hidden()

                            ProgressView()
                        }
                    case .loaded(let weather, let date, _):
                        WeatherView(weather: weather)
                        if Prefs.shared.showFooter {
                            WeatherFooterView(date: date, locationName: weather.locationName)
                        }
                    case .failed(let error):
                        VStack(alignment: .leading) {
                            WeatherErrorView(error: error)
                            Button("Retry", systemImage: "arrow.clockwise") {
                                retryID += 1
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .overlay(
                    VStack {
                        Divider()
                        Spacer()
                        Divider()
                    }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            }

            Section("Settings") {
                Toggle(isOn: $prefs.showFooter) {
                    VStack(alignment: .leading) {
                        Text("Show footer")
                        Text("Location and update time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    WorkWeatherSettingsView(currentLocation: location)
                } label: {
                    VStack(alignment: .leading) {
                        Text("Work weather")
                        Text(prefs.workWeatherSettings.location?.name ?? "Not configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if case let .loaded(weather, _, _) = state, let alert = weather.alert {
                    Button("Dismiss Alert") {
                        Prefs.shared.ignore(alert: alert)
                    }
                }
            }

            if case let .loaded(_, _, refreshError) = state, let refreshError {
                Section("Weather Refresh") {
                    Text("Couldn’t refresh weather. Showing the last update.")
                        .foregroundStyle(.yellow)
                    Text(refreshError.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry", systemImage: "arrow.clockwise") {
                        retryID += 1
                    }
                }
            }

            if let locationRefreshError, let retryLocation {
                Section("Location Refresh") {
                    Text("Couldn’t refresh location.")
                        .foregroundStyle(.yellow)
                    Text(locationRefreshError.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry", systemImage: "arrow.clockwise") {
                        retryLocation()
                    }
                }
            }
        }
        .task(id: LoadID(
            location: location,
            now: now,
            workSettings: prefs.workWeatherSettings,
            retryID: retryID
        )) {
            let loadDate = Date.now
            do {
                let weatherData = try await WeatherData.load(
                    location: location,
                    now: loadDate,
                    workSettings: prefs.workWeatherSettings
                )
                try Task.checkCancellation()
                state = .loaded(weatherData, date: loadDate, refreshError: nil)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                if case let .loaded(weather, date, _) = state {
                    state = .loaded(weather, date: date, refreshError: error)
                } else {
                    state = .failed(error)
                }
            }
        }
    }

    private struct LoadID: Hashable {
        let latitude: CLLocationDegrees
        let longitude: CLLocationDegrees
        let now: Date
        let workSettings: WorkWeatherSettings
        let retryID: Int

        init(
            location: CLLocation,
            now: Date,
            workSettings: WorkWeatherSettings,
            retryID: Int
        ) {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            self.now = now
            self.workSettings = workSettings
            self.retryID = retryID
        }
    }
}

#Preview {
    NavigationStack {
        WeatherPreviewView(location: previewLocation, now: Date())
    }
}
