import Foundation
import Combine
import RealityKit

class MakerViewModel: ObservableObject {
    @Published var checkpoints: [Checkpoint] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to MockDatabase updates
        MockDatabaseService.shared.$checkpoints
            .assign(to: \.checkpoints, on: self)
            .store(in: &cancellables)
    }
    
    func addCheckpointAt(transform: SIMD3<Float>, title: String, description: String) {
        let newCheckpoint = Checkpoint(
            title: title,
            taskDescription: description,
            relativeX: transform.x,
            relativeY: transform.y,
            relativeZ: transform.z
        )
        MockDatabaseService.shared.saveCheckpoint(newCheckpoint)
    }
}
