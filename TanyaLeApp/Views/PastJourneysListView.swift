//
//  PastJourneysListView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 08/07/26.
//

import SwiftUI

/// Shows all past journeys created by the maker.
/// Allows viewing, editing, and managing existing journeys.
struct PastJourneysListView: View {
    @Environment(\.dismiss) private var dismiss
    var journeyService = JourneyService.shared
    
    var body: some View {
        NavigationView {
            List {
                // Published Journeys
                if !journeyService.getPublishedJourneys().isEmpty {
                    Section(header: Text("Published")) {
                        ForEach(journeyService.getPublishedJourneys()) { journey in
                            JourneyRow(journey: journey)
                        }
                    }
                }
                
                // Draft Journeys
                if !journeyService.getDraftJourneys().isEmpty {
                    Section(header: Text("Drafts")) {
                        ForEach(journeyService.getDraftJourneys()) { journey in
                            JourneyRow(journey: journey)
                        }
                    }
                }
                
                // Empty State
                if journeyService.journeys.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        Text("No journeys yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Create your first journey to get started!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .navigationTitle("My Journeys")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Row view for displaying a single journey in the list
struct JourneyRow: View {
    let journey: Journey
    
    var body: some View {
        NavigationLink(destination: JourneyDetailView(journey: journey)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(journey.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    if journey.isPublished {
                        Label("Published", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Draft", systemImage: "pencil.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                if !journey.description.isEmpty {
                    Text(journey.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Label("\(journey.checkpointIDs.count) checkpoints", systemImage: "mappin.circle")
                    
                    Spacer()
                    
                    Text(journey.createdDate.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    PastJourneysListView()
}
