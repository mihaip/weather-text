import AuthenticationServices
import WeatherKit
import SwiftUI

struct ContentView: View {
    @StateObject var locationDataManager = LocationDataManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()

    var body: some View {
        NavigationView {
            VStack {
                switch locationDataManager.state {
                case .available(let location):
                    ScrollView {
                        WeatherPreviewView(location: location, now: now)
                    }
                        // Refresh the preview date and location so that we
                        // don't display overly stale data when resuming the app.
                        .onChange(of: scenePhase) {
                            if scenePhase == .active {
                                locationDataManager.refreshIfNeeded()
                                now = Date()
                            }
                        }
                case .notDetermined:
                    ScrollView {
                        VStack(spacing: 8) {
                            Text("Weather Text shows a brief textual summary of your current location's weather in a widget or complication.")
                            Button("Use Location", systemImage: "location.fill") {
                                locationDataManager.requestAuthorization()
                            }
                                .buttonStyle(BorderedButtonStyle(tint: .teal))
                            Button("Learn More") {
                                let url = URL(string: "https://github.com/mihaip/weather-text#weather-text")!
                                // There's no SFSafariViewController on watchOS, but a
                                // ASWebAuthenticationSession (ephemeral so that there's
                                // no prompt) is a reasonable approximation.
                                let session = ASWebAuthenticationSession(
                                   url: url,
                                   callbackURLScheme: nil
                               ) { _, _ in

                               }
                               session.prefersEphemeralWebBrowserSession = true
                               session.start()
                            }
                                .buttonStyle(.plain)
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
