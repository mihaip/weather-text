import SwiftUI

struct WeatherView : View {
    var weather: WeatherData
    @ScaledMetric private var mediumSpacing = 6
    @ScaledMetric private var smallSpacing = 2

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
            if let alert = weather.alert, Prefs.shared.shouldShow(alert: alert) {
                HStack(spacing: mediumSpacing) {
                    Image(systemName: alert.severity.symbol)
                    Text(alert.summary)
                }
                .font(.callout)
                .foregroundStyle(alert.severity.color)
            } else if let workWeather = weather.workWeather, workWeather.expiresAt > Date.now {
                HStack(spacing: mediumSpacing) {
                    Text("Work")
                        .foregroundStyle(.secondary)
                    if workWeather.symbol != weather.currentSymbol {
                        Image(systemName: workWeather.symbol)
                    }
                    Text("High ")
                        + Text(workWeather.highTemperature, format: temperatureFormat)
                    workWeather.differenceSummary(currentDailyHigh: weather.highTemperature)
                }
                .font(.callout)
                .scaledToFill()
                .minimumScaleFactor(0.75)
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

extension WorkWeatherInsight {
    func differenceSummary(currentDailyHigh: Measurement<UnitTemperature>) -> Text {
        switch reason {
        case .precipitation(let kind, let chance):
            return Text("\(kind) \(chance, format: .percent.precision(.fractionLength(0)))")
                .foregroundStyle(Color.blue.opacity(0.65))
        case .lowerHigh:
            return (formatHighDifference(from: currentDailyHigh) + Text(" cooler"))
                .foregroundStyle(Color.blue.opacity(0.65))
        case .higherHigh:
            return (formatHighDifference(from: currentDailyHigh) + Text(" hotter"))
                .foregroundStyle(Color.orange.opacity(0.65))
        }
    }

    func formatHighDifference(from currentDailyHigh: Measurement<UnitTemperature>) -> Text {
        let displayUnit = UnitTemperature(forLocale: .autoupdatingCurrent)

        // Round before subtracting so that the displayed value is consistent
        // with subtracting the rounded display of the current and work high.
        let workHigh = highTemperature.converted(to: displayUnit).value.rounded(.toNearestOrEven)
        let currentHigh = currentDailyHigh.converted(to: displayUnit).value.rounded(.toNearestOrEven)

        return Text(
            Measurement(value: abs(workHigh - currentHigh), unit: displayUnit),
            format: WorkWeatherInsight.temperatureDifferenceFormat)
    }

    private static let temperatureDifferenceFormat: Measurement<UnitTemperature>.FormatStyle = .measurement(
        width: .narrow,
        usage: .asProvided,
        hidesScaleName: true,
        numberFormatStyle: FloatingPointFormatStyle<Double>().precision(.fractionLength(0))
    )
}

private let temperatureFormat: Measurement<UnitTemperature>.FormatStyle = .measurement(
    width: .narrow,
    hidesScaleName: true,
    numberFormatStyle: FloatingPointFormatStyle<Double>().precision(.fractionLength(0))
)
