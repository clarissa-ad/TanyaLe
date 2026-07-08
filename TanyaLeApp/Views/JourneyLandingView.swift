//
//  JourneyLandingView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 08/07/26.
//

import SwiftUI

/// Landing page for the maker flow.
/// Shows app logo and two main actions: create a new journey or view past journeys.
struct JourneyLandingView: View {
    @State private var showCreateJourney = false
    @State private var showPastJourneys = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // App Logo
                    VStack(spacing: 16) {
                        Image("appicon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .shadow(color: .blue.opacity(0.3), radius: 20)
                        
                        Text("TanyaLe")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Create immersive AR journeys")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 20) {
                        // Create New Journey Button
                        Button {
                            showCreateJourney = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("Create New Journey")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                        }
                        
                        // View Past Journeys Button
                        Button {
                            showPastJourneys = true
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.title2)
                                Text("View Past Journeys")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: .gray.opacity(0.2), radius: 5, y: 2)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateJourney) {
                // TODO: Navigate to JourneySetupView
                Text("Create Journey - Coming Soon")
                    .font(.title)
                    .padding()
            }
            .sheet(isPresented: $showPastJourneys) {
                // TODO: Navigate to PastJourneysListView
                Text("Past Journeys - Coming Soon")
                    .font(.title)
                    .padding()
            }
        }
    }
}

#Preview {
    JourneyLandingView()
}
