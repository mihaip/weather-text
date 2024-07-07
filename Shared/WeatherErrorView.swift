import SwiftUI

struct WeatherErrorView: View {
    var error: Error
    @ScaledMetric private var spacing = 6

    var body: some View {
        HStack(spacing: spacing) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Unavailable")
        }
        .foregroundStyle(.red)
        .font(.headline)
        .scaledToFill()
        .minimumScaleFactor(0.8)
        Text(error.localizedDescription)
            .font(.caption)
    }
}
