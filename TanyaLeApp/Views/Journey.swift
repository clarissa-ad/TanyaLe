//
//  Journey.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 08/07/26.
//

import Foundation
import CoreLocation

/// Represents a complete AR journey created by a maker.
/// Contains metadata, starting point coordinates, and associated checkpoints.
// Hashable so a Journey can drive `navigationDestination(item:)`.
struct Journey: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var description: String
    var createdDate: Date
    
    // GPS coordinates for the journey start point
    var startLatitude: Double
    var startLongitude: Double
    
    // AR world origin (relative coordinates)
    // These are set when the maker establishes the start point
    var arOriginX: Float
    var arOriginY: Float
    var arOriginZ: Float
    
    // Associated checkpoint IDs
    var checkpointIDs: [UUID]
    
    // QR code data (generated after journey is complete)
    var qrCodeData: String?
    
    // Status
    var isPublished: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        createdDate: Date = Date(),
        startLatitude: Double = 0,
        startLongitude: Double = 0,
        arOriginX: Float = 0,
        arOriginY: Float = 0,
        arOriginZ: Float = 0,
        checkpointIDs: [UUID] = [],
        qrCodeData: String? = nil,
        isPublished: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdDate = createdDate
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.arOriginX = arOriginX
        self.arOriginY = arOriginY
        self.arOriginZ = arOriginZ
        self.checkpointIDs = checkpointIDs
        self.qrCodeData = qrCodeData
        self.isPublished = isPublished
    }
    
    /// Returns the start point as a CLLocationCoordinate2D
    var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
    }
    
    /// Returns true if the journey has a valid start point set
    var hasStartPoint: Bool {
        startLatitude != 0 && startLongitude != 0
    }
}
