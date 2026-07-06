//
//  WalkableAspiration.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 05/07/26.
//

import Foundation
import CoreLocation

struct WalkableAspiration: Identifiable, Codable {
    var id = UUID()
    var message: String
    
    // Location
    var latitude: Double
    var longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
