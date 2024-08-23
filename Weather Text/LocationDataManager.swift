import Foundation
import CoreLocation

enum LocationState {
    case available(CLLocation)
    case waiting
    case notDetermined
    case denied
    case restricted
    case error(Error)
}

class LocationDataManager : NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var state: LocationState

    private var locationManager = CLLocationManager()
    private var lastLocationUpdate = Date()

    override init() {
        // locationManagerDidChangeAuthorization will be called when the location
        // manager is created, so the initial value is not that that interesting.
        state = .notDetermined
        super.init()
        locationManager.delegate = self
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            state = .waiting
            locationManager.requestLocation()
        case .restricted:
            state = .restricted
        case .denied:
            state = .denied
        case .notDetermined:
            state = .notDetermined
        @unknown default:
            print("unexpected authorization status: \(manager.authorizationStatus)")
        }
    }

    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func refreshIfNeeded() {
        if Date.now.timeIntervalSince(lastLocationUpdate) > 60 * 60 {
            locationManager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        state = .available(locations.last!)
        lastLocationUpdate = Date.now
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        state = .error(error)
    }
}
