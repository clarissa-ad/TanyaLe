import Foundation
import CoreLocation
import Observation

@Observable class LocationManager: NSObject, CLLocationManagerDelegate {
    // @Observable tracks plain stored properties; @Published would conflict
    // with the macro's generated init accessors (and requires ObservableObject).
    @ObservationIgnored private let locationManager = CLLocationManager()

    var userLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
    }
}
