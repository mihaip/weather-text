import CoreLocation
import Foundation

class LocationFetcher : NSObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager
    private var completion: ((Result<CLLocation, Error>) -> ())?

    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.delegate = self
    }

    func fetch (_ completion: @escaping (Result<CLLocation, Error>) -> Void) {
        self.completion = completion
        if let location = locationManager.location {
            completion(.success(location))
        } else {
            locationManager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let completion else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .restricted:
            completion(.failure(LocationFetcherError.restricted))
        case .denied:
            completion(.failure(LocationFetcherError.denied))
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        @unknown default:
            completion(.failure(LocationFetcherError.unknownAuthorizationStatus(manager.authorizationStatus)))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let completion else { return }
        completion(.success(locations.last!))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let completion else { return }
        completion(.failure(error))
    }
}

enum LocationFetcherError : Error {
    case restricted
    case denied
    case unknownAuthorizationStatus(CLAuthorizationStatus)
}
