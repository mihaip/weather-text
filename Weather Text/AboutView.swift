import SwiftUI
import WeatherKit

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attributionState = AttributionState.loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if case .loaded(let attribution) = attributionState {
                    Link(destination: attribution.legalPageURL) {
                        AsyncImage(url: markURL(for: attribution)) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(height: 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }

                Text(aboutText)
                    .tint(.mint)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if case .loading = attributionState {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("About")
        .task {
            do {
                attributionState = .loaded(try await WeatherService.shared.attribution)
            } catch {
                attributionState = .failed
            }
        }
    }

    private var aboutText: AttributedString {
        var text = AttributedString("Weather Text\n")
        text.font = .headline
        text.foregroundColor = .mint

        var summary = AttributedString(
            "A small Apple Watch app that shows a brief textual summary of the weather.\n\n"
        )
        summary.font = .body
        text.append(summary)

        var weatherIntro = AttributedString("Weather data is provided by ")
        weatherIntro.font = .body
        text.append(weatherIntro)

        switch attributionState {
        case .loading, .failed:
            var provider = AttributedString("Apple Weather")
            provider.font = .body.bold()
            text.append(provider)
        case .loaded(let attribution):
            text.append(link(attribution.serviceName, destination: attribution.legalPageURL))

            var legalText = AttributedString(".\n\(attribution.legalAttributionText)")
            legalText.font = .caption
            legalText.foregroundColor = .secondary
            text.append(legalText)
        }

        let linksIntro = AttributedString(
            attributionState.isLoaded ? "\n\n" : ".\n\n"
        )
        text.append(linksIntro)
        text.append(link("Source code", destination: Self.repositoryURL))

        var separator = AttributedString("  ·  ")
        separator.foregroundColor = .secondary
        text.append(separator)
        text.append(link("Privacy policy", destination: Self.privacyPolicyURL))

        return text
    }

    private func link(_ title: String, destination: URL) -> AttributedString {
        var link = AttributedString(title)
        link.font = .body.bold()
        link.link = destination
        return link
    }

    private func markURL(for attribution: WeatherAttribution) -> URL {
        colorScheme == .light
            ? attribution.combinedMarkLightURL
            : attribution.combinedMarkDarkURL
    }

    private enum AttributionState {
        case loading
        case loaded(WeatherAttribution)
        case failed

        var isLoaded: Bool {
            if case .loaded = self {
                return true
            }
            return false
        }
    }

    private static let repositoryURL = URL(string: "https://github.com/mihaip/weather-text")!
    private static let privacyPolicyURL = URL(
        string: "https://github.com/mihaip/weather-text/blob/main/Docs/Privacy%20Policy.md#privacy-policy"
    )!
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
