import Foundation
import CoreLocation
import Observation

/// App-wide GPS source, shared by every screen.
///
/// A single instance matters: each `CLLocationManager` cold-starts its own
/// fix, so per-screen instances made "GPS Initializing…" take tens of seconds
/// on *every* screen. With one shared manager the fix is acquired once and
/// stays warm for the whole session.
@Observable class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    // @Observable tracks plain stored properties; @Published would conflict
    // with the macro's generated init accessors (and requires ObservableObject).
    @ObservationIgnored private let locationManager = CLLocationManager()

    var userLocation: CLLocation?
    /// Mirrored so views can tell "waiting for a GPS fix" apart from
    /// "permission denied" instead of spinning forever.
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        locationManager.delegate = self
        // Use kCLLocationAccuracyNearestTenMeters for faster acquisition
        // This is sufficient for journey start points (±10m accuracy)
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        // Reduce distance filter for faster updates
        locationManager.distanceFilter = 5 // Update every 5 meters
    }

    func requestPermission() {
        // Prompts only while status is .notDetermined. Updates are started in
        // locationManagerDidChangeAuthorization once the user grants access —
        // the system guarantees that callback fires with the initial status
        // and again whenever the user answers the prompt.
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Seed with the system's cached last-known fix so the UI shows a
            // usable location instantly instead of waiting for a fresh one.
            if userLocation == nil, let cached = manager.location {
                userLocation = cached
            }
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager failed: \(error.localizedDescription)")
    }
    
    // Optional: Method to upgrade accuracy when user is ready to set start point
    // or needs a steady update stream (e.g. the walk-to-start gate, where the
    // 5 m distance filter would stop updates while the user stands still).
    func improveAccuracy() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
    }
    
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }
}
