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
            .navigationTitle {
                Text("Weather Text").foregroundColor(.mint)
            }
        }
    }

}

#Preview {
    ContentView()
}
