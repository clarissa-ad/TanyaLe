import Foundation
import Combine
import RealityKit
import CoreLocation

class MakerViewModel: ObservableObject {
    @Published var checkpoints: [Checkpoint] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to MockDatabase updates
        MockDatabaseService.shared.$checkpoints
            .assign(to: \.checkpoints, on: self)
            .store(in: &cancellables)
    }
    
    func addCheckpointAt(transform: SIMD3<Float>, title: String, description: String, interactionType: InteractionType, surveyOptions: [String], overrideLocation: CLLocationCoordinate2D? = nil) {
        
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
            surveyOptions: surveyOptions,
            latitude: finalLat,
            longitude: finalLon,
            relativeX: transform.x,
            relativeY: transform.y,
            relativeZ: transform.z
        )
        MockDatabaseService.shared.saveCheckpoint(newCheckpoint)
    }
}
