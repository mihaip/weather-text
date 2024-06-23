import WeatherKit
import SwiftUI

struct ContentView: View {
    @StateObject var locationDataManager = LocationDataManager()

    var body: some View {
        VStack {
            switch locationDataManager.state {
            case .available(let location):
                Text("Your current location is:")
                Text("Latitude: \(location.coordinate.latitude.description)")
                Text("Longitude: \(location.coordinate.longitude.description)")
                Button("Get Weather") {
                    print("getting weather")
                    Task {
                        var output: String
                        do {
                            output = try await WeatherService.shared.weather(for: location).currentWeather.temperature.debugDescription
                        } catch {
                            output = "Error: \(error.localizedDescription)"
                        }
                        print(output)
                    }
                }

            case .notDetermined:
                Button("Request Location") {
                    locationDataManager.requestAuthorization()
                }
            case .waiting:
                ProgressView()
            case .restricted:
                Text("Restricted")
            case .denied:
                Text("Denied")
            case .error(let error):
                Text("Error: \(error.localizedDescription)")
            }
        }
        .padding()
    }

}

#Preview {
    ContentView()
}
