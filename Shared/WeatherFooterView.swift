import SwiftUI

struct WeatherFooterView : View {
    var date: Date
    var locationName: String?

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            if let locationName {
                Text(locationName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.trailing)
                Text("-")
                    .padding(.trailing)
            }
            Text(date, style: .time)
        }
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack(spacing: 10) {
        WeatherFooterView(date: Date())
        WeatherFooterView(date: Date(), locationName: "Cupertino, CA")
        WeatherFooterView(date: Date(), locationName: "Taumatawhakatangihangakoauauotamateapokaiwhenuakitanatahu, NZ")
    }
}
