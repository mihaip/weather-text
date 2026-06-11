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
    @Published var refreshError: Error?

    private var locationManager = CLLocationManager()
    private var lastLocationUpdate: Date?
    private var isRequestingLocation = false

    override init() {
        // locationManagerDidChangeAuthorization will be called when the location
        // manager is created, so the initial value is not that that interesting.
        state = .notDetermined
        refreshError = nil
        super.init()
        locationManager.delegate = self
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            refresh()
        case .restricted:
            isRequestingLocation = false
            state = .restricted
        case .denied:
            isRequestingLocation = false
            state = .denied
        case .notDetermined:
            isRequestingLocation = false
            state = .notDetermined
        @unknown default:
            print("unexpected authorization status: \(manager.authorizationStatus)")
        }
    }

    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func refreshIfNeeded() {
        guard let lastLocationUpdate else {
            refresh()
            return
        }
        if Date.now.timeIntervalSince(lastLocationUpdate) > 60 * 60 {
            refresh()
        }
    }

    func refresh() {
        guard !isRequestingLocation else {
            return
        }
        refreshError = nil
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            break
        case .restricted:
            state = .restricted
            return
        case .denied:
            state = .denied
            return
        case .notDetermined:
            state = .notDetermined
            return
        @unknown default:
            state = .error(LocationDataManagerError.unknownAuthorizationStatus)
            return
        }
        if case .available = state {
            // Keep displaying the last usable location while refreshing.
        } else {
            state = .waiting
        }
        isRequestingLocation = true
        locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isRequestingLocation = false
        guard let location = locations.last else {
            handle(error: LocationDataManagerError.noLocations)
            return
        }
        refreshError = nil
        state = .available(location)
        lastLocationUpdate = Date.now
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isRequestingLocation = false
        handle(error: error)
    }

    private func handle(error: Error) {
        if case .available = state {
            refreshError = error
        } else {
            state = .error(error)
        }
    }
}

enum LocationDataManagerError: LocalizedError {
    case noLocations
    case unknownAuthorizationStatus

    var errorDescription: String? {
        switch self {
        case .noLocations:
            return "No location was returned."
        case .unknownAuthorizationStatus:
            return "Location access has an unknown authorization status."
        }
    }
}
