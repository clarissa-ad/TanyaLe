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
    
    func addCheckpointAt(transform: SIMD3<Float>) {
        let newCheckpoint = Checkpoint(
            title: "New Checkpoint \(checkpoints.count + 1)",
            taskDescription: "Please complete this task.",
            relativeX: transform.x,
            relativeY: transform.y,
            relativeZ: transform.z
        )
        MockDatabaseService.shared.saveCheckpoint(newCheckpoint)
    }
}
