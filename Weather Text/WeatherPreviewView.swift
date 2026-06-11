import CoreLocation
import SwiftUI

struct WeatherPreviewView: View {
    var location: CLLocation
    let now: Date

    enum WeatherState {
      case loading
      case loaded(WeatherData, date: Date, refreshError: Error?)
      case failed(Error)
    }
    @State private var state = WeatherState.loading
    @State private var retryID = 0
    @ObservedObject var prefs = Prefs.shared

    var body: some View {
        VStack(alignment: .leading) {
            Text("Weather widget and complication ready to be added.")
                .padding(.bottom, 4)
            Text("Preview")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                switch state {
                case .loading:
                    ProgressView()
                        .padding(.vertical, 12)
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
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.secondary, lineWidth: 1)
                )
            Text("Settings")
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Toggle("Show footer", isOn: $prefs.showFooter)
            if case let .loaded(weather, _, refreshError) = state {
                if let alert = weather.alert {
                    Button("Dismiss Alert") {
                        Prefs.shared.ignore(alert: alert)
                    }
                    .padding(.top, 8)
                    .buttonStyle(BorderedButtonStyle())
                }
                if let refreshError {
                    VStack(alignment: .leading) {
                        Text("Couldn’t refresh weather. Showing the last update.")
                            .foregroundStyle(.yellow)
                        Text(refreshError.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry", systemImage: "arrow.clockwise") {
                            retryID += 1
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                    .padding(.top, 8)
                }
            }
        }
        .task(id: LoadID(location: location, now: now, retryID: retryID)) {
            let loadDate = Date.now
            do {
                let weatherData = try await WeatherData.load(location: location, now: loadDate)
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
        let retryID: Int

        init(location: CLLocation, now: Date, retryID: Int) {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            self.now = now
            self.retryID = retryID
        }
    }
}

#Preview {
    ScrollView {
        WeatherPreviewView(location: previewLocation, now: Date())
    }
}
