import CoreLocation
import Foundation

class LocationFetcher : NSObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager
    private var completions: [(Result<CLLocation, Error>) -> Void] = []
    private let maximumCachedLocationAge: TimeInterval = 15 * 60
    private let maximumCachedLocationAccuracy: CLLocationAccuracy = 10_000

    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.delegate = self
    }

    func fetch (_ completion: @escaping (Result<CLLocation, Error>) -> Void) {
        completions.append(completion)
        guard completions.count == 1 else {
            return
        }
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = freshCachedLocation {
                finish(.success(location))
            } else {
                locationManager.requestLocation()
            }
        case .restricted:
            finish(.failure(LocationFetcherError.restricted))
        case .denied:
            finish(.failure(LocationFetcherError.denied))
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        @unknown default:
            finish(.failure(LocationFetcherError.unknownAuthorizationStatus(locationManager.authorizationStatus)))
        }
    }

    private var freshCachedLocation: CLLocation? {
        guard let location = locationManager.location,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maximumCachedLocationAccuracy,
              Date.now.timeIntervalSince(location.timestamp) >= 0,
              Date.now.timeIntervalSince(location.timestamp) <= maximumCachedLocationAge else {
            return nil
        }
        return location
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard !completions.isEmpty else {
            return
        }
        let pendingCompletions = completions
        completions.removeAll()
        for completion in pendingCompletions {
            completion(result)
        }
    }

    private func requestLocationIfNeeded() {
        guard !completions.isEmpty else {
            return
        }
        if let location = freshCachedLocation {
            finish(.success(location))
        } else {
            locationManager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !completions.isEmpty else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocationIfNeeded()
        case .restricted:
            finish(.failure(LocationFetcherError.restricted))
        case .denied:
            finish(.failure(LocationFetcherError.denied))
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        @unknown default:
            finish(.failure(LocationFetcherError.unknownAuthorizationStatus(manager.authorizationStatus)))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !completions.isEmpty else { return }
        guard let location = locations.last else {
            finish(.failure(LocationFetcherError.noLocations))
            return
        }
        finish(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }
}

enum LocationFetcherError: LocalizedError {
    case restricted
    case denied
    case noLocations
    case unknownAuthorizationStatus(CLAuthorizationStatus)

    var errorDescription: String? {
        switch self {
        case .restricted:
            return "Location access is restricted."
        case .denied:
            return "Location access was denied."
        case .noLocations:
            return "No location was returned."
        case .unknownAuthorizationStatus:
            return "Location access has an unknown authorization status."
        }
    }
}
