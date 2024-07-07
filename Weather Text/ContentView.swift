import WeatherKit
import SwiftUI

struct ContentView: View {
    @StateObject var locationDataManager = LocationDataManager()

    var body: some View {
        NavigationView {
            VStack {
                switch locationDataManager.state {
                case .available(let location):
                    ScrollView {
                        WeatherPreviewView(location: location, now: Date())
                    }
                case .notDetermined:
                    ScrollView {
                        Text("Weather Text shows a brief textual summary of your current location's weather in a widget or complication.")
                            .padding(.bottom, 8)
                        Button("Current Location", systemImage: "location.fill") {
                            locationDataManager.requestAuthorization()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .waiting:
                    ProgressView()
                case .restricted:
                    Text("Location information is restricted, please check with your device adminstrator.")
                case .denied:
                    Text("Location access was not granted, please check your device settings.")
                case .error(let error):
                    Text("Encountered an error getting location information.")
                    Text(error.localizedDescription)
                }
            }
            .navigationTitle {
                Text("Weather Text").foregroundColor(.mint)
            }
        }
    }

}

#Preview {
    ContentView()
}
