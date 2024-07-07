import SwiftUI

struct WeatherView : View {
    var weather: WeatherData
    @ScaledMetric private var mediumSpacing = 6
    @ScaledMetric private var smallSpacing = 2

    private let temperatureFormat: Measurement<UnitTemperature>.FormatStyle = .measurement(
        width: .narrow,
        hidesScaleName: true,
        numberFormatStyle: FloatingPointFormatStyle<Double>().precision(.fractionLength(0))
    )

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: mediumSpacing) {
                Image(systemName: weather.currentSymbol)
                Text(weather.currentTemperature, format: temperatureFormat)
                Text(weather.currentCondition.description)
            }
            .font(.headline)
            .scaledToFill()
            .minimumScaleFactor(0.8)
            HStack(spacing: 0) {
                Text("Low:")
                    .padding([.trailing], smallSpacing)
                Text(weather.lowTemperature, format: temperatureFormat)
                    .padding([.trailing], mediumSpacing)
                Text("High:")
                    .padding([.trailing], smallSpacing)
                Text(weather.highTemperature, format: temperatureFormat)
            }
            .font(.subheadline)
            .scaledToFill()
            .minimumScaleFactor(0.8)
            if let alert = weather.alert {
                HStack(spacing: mediumSpacing) {
                    Image(systemName: alert.severity.symbol)
                    Text(alert.summary)
                }
                .font(.callout)
                .foregroundStyle(alert.severity.color)
            } else if let sunEvent = weather.sunEvent {
                HStack(spacing: 0) {
                    switch sunEvent {
                    case .sunrise(let date):
                        Text("Sunrise:")
                            .padding([.trailing], smallSpacing)
                        Text(date, style: .time)
                    case .sunset(let date):
                        Text("Sunset:")
                            .padding([.trailing], smallSpacing)
                        Text(date, style: .time)
                    }
                }
                .foregroundStyle(.secondary)
                .scaledToFill()
                .minimumScaleFactor(0.8)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }
}
