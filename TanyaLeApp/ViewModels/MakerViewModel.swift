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
    
    func addCheckpointAt(transform: SIMD3<Float>, location: CLLocation, title: String, description: String) {
        let newCheckpoint = Checkpoint(
            title: title,
            taskDescription: description,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            relativeX: transform.x,
            relativeY: transform.y,
            relativeZ: transform.z
        )
        MockDatabaseService.shared.saveCheckpoint(newCheckpoint)
    }
}
