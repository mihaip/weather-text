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

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .loaded(let weather):
                VStack(alignment: .leading) {
                    Text("Weather widget and complication ready to be added.")
                        .padding(.bottom, 4)
                    Text("Preview")
                        .foregroundStyle(.secondary)
                    WeatherView(weather: weather)
                        .padding(8)
                        .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.secondary, lineWidth: 1)
                            )
                }
            case .failed(let error):
                WeatherErrorView(error: error)
            }
        }
        .task {
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
    WeatherPreviewView(location: CLLocation(latitude: 37.3230, longitude: 122.0322), now: Date())
}
