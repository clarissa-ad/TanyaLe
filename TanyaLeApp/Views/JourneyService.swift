//
//  JourneyService.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 08/07/26.
//

import Foundation
import Observation

/// Mock service for managing journeys.
/// In production, this would connect to a real database or API.
@Observable
class JourneyService {
    static let shared = JourneyService()
    
    private(set) var journeys: [Journey] = []
    
    private init() {
        loadMockData()
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new journey
    func createJourney(_ journey: Journey) {
        journeys.append(journey)
        saveToStorage()
    }
    
    /// Update an existing journey
    func updateJourney(_ journey: Journey) {
        if let index = journeys.firstIndex(where: { $0.id == journey.id }) {
            journeys[index] = journey
            saveToStorage()
        }
    }
    
    /// Delete a journey
    func deleteJourney(_ id: UUID) {
        journeys.removeAll { $0.id == id }
        saveToStorage()
    }
    
    /// Get a specific journey by ID
    func getJourney(by id: UUID) -> Journey? {
        journeys.first { $0.id == id }
    }
    
    /// Get all published journeys
    func getPublishedJourneys() -> [Journey] {
        journeys.filter { $0.isPublished }
    }
    
    /// Get all draft (unpublished) journeys
    func getDraftJourneys() -> [Journey] {
        journeys.filter { !$0.isPublished }
    }
    
    // MARK: - Checkpoint Association
    
    /// Add a checkpoint to a journey
    func addCheckpoint(_ checkpointID: UUID, to journeyID: UUID) {
        if let index = journeys.firstIndex(where: { $0.id == journeyID }) {
            if !journeys[index].checkpointIDs.contains(checkpointID) {
                journeys[index].checkpointIDs.append(checkpointID)
                saveToStorage()
            }
        }
    }
    
    /// Remove a checkpoint from a journey
    func removeCheckpoint(_ checkpointID: UUID, from journeyID: UUID) {
        if let index = journeys.firstIndex(where: { $0.id == journeyID }) {
            journeys[index].checkpointIDs.removeAll { $0 == checkpointID }
            saveToStorage()
        }
    }
    
    // MARK: - Publishing
    
    /// Publish a journey (generate QR code and make it available)
    func publishJourney(_ id: UUID) {
        if let index = journeys.firstIndex(where: { $0.id == id }) {
            // Generate QR code data (in production, this would be a proper encoding)
            journeys[index].qrCodeData = generateQRCodeData(for: journeys[index])
            journeys[index].isPublished = true
            saveToStorage()
        }
    }
    
    private func generateQRCodeData(for journey: Journey) -> String {
        // In production, encode journey data as JSON or URL
        let data: [String: Any] = [
            "journeyID": journey.id.uuidString,
            "name": journey.name,
            "startLat": journey.startLatitude,
            "startLng": journey.startLongitude
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return journey.id.uuidString
    }
    
    // MARK: - Persistence (Mock)
    
    private func saveToStorage() {
        // In production: Save to UserDefaults, CoreData, or cloud database
        // For now, just in-memory
    }
    
    private func loadMockData() {
        // Add some sample journeys for testing
        let sampleJourney = Journey(
            name: "Museum Tour",
            description: "Explore the science exhibits",
            startLatitude: 37.7749,
            startLongitude: -122.4194,
            isPublished: true
        )
        journeys.append(sampleJourney)
    }
}
