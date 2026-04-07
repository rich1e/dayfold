// Services/WeatherService.swift
import Foundation
import CoreLocation
import WeatherKit

struct WeatherData {
    let temperature: Double
    let condition: String
    let symbolName: String
}

class WeatherService {
    static let shared = WeatherService()

    private let weatherService = WeatherKit.WeatherService.shared

    func fetchWeather(for location: CLLocation) async throws -> WeatherData {
        let weather = try await weatherService.weather(
            for: location
        )

        let currentWeather = weather.currentWeather
        let temperature = currentWeather.temperature.value
        let condition = currentWeather.condition.description
        let symbolName = currentWeather.symbolName

        return WeatherData(
            temperature: temperature,
            condition: condition,
            symbolName: symbolName
        )
    }

    func fetchWeatherIfPossible(for location: CLLocation?) async -> WeatherData? {
        guard let location = location else { return nil }

        do {
            return try await fetchWeather(for: location)
        } catch {
            print("Weather fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}
