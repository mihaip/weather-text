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
                        VStack {
                            WeatherPreviewView(location: location, now: now)
                            if let error = locationDataManager.refreshError {
                                RefreshErrorView(
                                    message: "Couldn’t refresh location.",
                                    error: error,
                                    retry: locationDataManager.refresh
                                )
                            }
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
                    ScrollView {
                        Text("Location information is restricted, please check with your device administrator.")
                    }
                case .denied:
                    ScrollView {
                        VStack {
                            Text("Location access was not granted. Enable it in Settings, then try again.")
                            Button("Try Again", systemImage: "arrow.clockwise") {
                                locationDataManager.refresh()
                            }
                        }
                    }
                case .error(let error):
                    ScrollView {
                        VStack {
                            WeatherErrorView(error: error)
                            Button("Retry", systemImage: "arrow.clockwise") {
                                locationDataManager.refresh()
                            }
                        }
                    }
                }
            }
            // Refresh the preview date and location even when the previous
            // attempt failed, so reopening the app can recover.
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    locationDataManager.refreshIfNeeded()
                    now = Date()
                }
            }
            .navigationTitle {
                Text("Weather Text").foregroundColor(.mint)
            }
        }
    }

}

private struct RefreshErrorView: View {
    let message: String
    let error: Error
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(message)
                .foregroundStyle(.yellow)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Retry", systemImage: "arrow.clockwise", action: retry)
        }
        .padding(.top, 8)
    }
}

#Preview {
    ContentView()
}
