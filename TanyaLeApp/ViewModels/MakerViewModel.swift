import Foundation
import Observation
import RealityKit
import CoreLocation

@Observable
class MakerViewModel {
    /// Mirrors the shared mock database. Observation tracks reads through
    /// this computed property, so views update when checkpoints change —
    /// no Combine subscription needed.
    var checkpoints: [Checkpoint] {
        MockDatabaseService.shared.checkpoints
    }

    func addCheckpointAt(transform: SIMD3<Float>, title: String, description: String, interactionType: Checkpoint.InteractionType, question: String, surveyOptions: [String], emojiLeft: String, emojiRight: String, selectedAssetId: String? = nil, assetRotationY: Float = 0, overrideLocation: CLLocationCoordinate2D? = nil) {
        
        let origin = overrideLocation ?? MockDatabaseService.shared.surveyOrigin ?? CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666)
        
        // 1 degree of latitude/longitude is very roughly 111,111 meters
        // We will apply a tiny offset so the map pins visually match the AR layout
        let latOffset = Double(transform.z) / 111111.0
        let lonOffset = Double(transform.x) / 111111.0
        
        let finalLat = origin.latitude + latOffset
        let finalLon = origin.longitude + lonOffset
        
        let newCheckpoint = Checkpoint(
            title: title,
            taskDescription: description,
            interactionType: interactionType,
            question: question,
            surveyOptions: surveyOptions,
            emojiLeft: emojiLeft.isEmpty ? "😡" : String(emojiLeft.prefix(1)),
            emojiRight: emojiRight.isEmpty ? "😍" : String(emojiRight.prefix(1)),
            selectedAssetId: selectedAssetId,
            assetRotationY: assetRotationY,
            latitude: finalLat,
            longitude: finalLon,
            relativeX: transform.x,
            relativeY: transform.y,
            relativeZ: transform.z
        )
        MockDatabaseService.shared.saveCheckpoint(newCheckpoint)
    }
}
