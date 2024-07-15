import CoreLocation
import SwiftUI

struct WeatherPreviewView: View {
    var location: CLLocation
    let now: Date

    enum WeatherState {
      case loading
      case loaded(WeatherData)
      case failed(Error)
    }
    @State private var state = WeatherState.loading
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
                case .loaded(let weather):
                        WeatherView(weather: weather)
                        if Prefs.shared.showFooter {
                            WeatherFooterView(date: now, locationName: weather.locationName)
                        }
                case .failed(let error):
                    WeatherErrorView(error: error)
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
        }
        .task(id: now) {
            do {
                let weatherData = try await WeatherData.load(location: location, now: now)
                state = .loaded(weatherData)
            } catch {
                state = .failed(error)
            }
        }
    }
}

#Preview {
    ScrollView {
        WeatherPreviewView(location: previewLocation, now: Date())
    }
}
