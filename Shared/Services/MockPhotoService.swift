import Foundation
import SwiftUI
import Observation

/// A mock service to hold photos in-memory for the AR Photobooth feature.
/// @Observable tracks the plain stored property; views that read `photos`
/// (directly or via fetchPhotos) re-render when it changes.
@MainActor
@Observable
class MockPhotoService {
    static let shared = MockPhotoService()

    // Maps a Checkpoint's UUID to an array of UIImages taken at that checkpoint.
    var photos: [UUID: [UIImage]] = [:]
    
    private init() {}
    
    /// Save a photo for a specific checkpoint
    func savePhoto(image: UIImage, forCheckpoint checkpointId: UUID) {
        if photos[checkpointId] != nil {
            photos[checkpointId]?.append(image)
        } else {
            photos[checkpointId] = [image]
        }
        print("MockPhotoService: Saved photo for checkpoint \(checkpointId). Total: \(photos[checkpointId]?.count ?? 0)")
    }
    
    /// Fetch all photos for a specific checkpoint
    func fetchPhotos(forCheckpoint checkpointId: UUID) -> [UIImage] {
        return photos[checkpointId] ?? []
    }
    
    /// Delete a specific photo for a checkpoint
    func deletePhoto(image: UIImage, forCheckpoint checkpointId: UUID) {
        guard var cpPhotos = photos[checkpointId] else { return }
        
        // Find by identity since UIImage doesn't easily equate by value in a simple array
        cpPhotos.removeAll(where: { $0 === image })
        photos[checkpointId] = cpPhotos
        
        print("MockPhotoService: Deleted photo for checkpoint \(checkpointId). Remaining: \(cpPhotos.count)")
    }
    
    // MARK: - Prompt Photos
    var promptPhotos: [String: UIImage] = [:]
    
    func savePromptPhoto(image: UIImage, id: String) {
        promptPhotos[id] = image
        print("MockPhotoService: Saved prompt photo with id \(id)")
    }
    
    func fetchPromptPhoto(id: String) -> UIImage? {
        return promptPhotos[id]
    }
}
