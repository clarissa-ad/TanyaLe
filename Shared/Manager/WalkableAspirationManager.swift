//
//  WalkableAspirationManager.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 05/07/26.
//

import Foundation
import Combine

/// In-memory store for the messages users leave in AR.
/// Mirrors the pattern used by MockDatabaseService for checkpoints, so it can
/// later be swapped for CloudKit without touching the views.
class WalkableAspirationManager: ObservableObject {
    @Published var showActionSheet: Bool = false
    @Published var aspirations: [WalkableAspiration] = []

    /// Save a newly dropped message pin.
    func add(_ aspiration: WalkableAspiration) {
        aspirations.append(aspiration)
        print("WalkableAspiration: saved \"\(aspiration.message)\" at \(aspiration.relativePosition)")
    }

    func delete(_ id: UUID) {
        aspirations.removeAll { $0.id == id }
    }
}
