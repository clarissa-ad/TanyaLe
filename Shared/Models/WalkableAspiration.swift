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

    // Relative physical offsets from the AR World Origin, in meters.
    // Same convention as Checkpoint: +X = east, +Y = up, -Z = true north
    // (because the AR session runs with .gravityAndHeading).
    var relativeX: Float
    var relativeY: Float
    var relativeZ: Float

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var relativePosition: SIMD3<Float> {
        SIMD3<Float>(relativeX, relativeY, relativeZ)
    }
}
