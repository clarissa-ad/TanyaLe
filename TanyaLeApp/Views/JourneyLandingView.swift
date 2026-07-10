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
    @State private var showPastJourneys = false
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo
                VStack(spacing: 16) {
                    Image("appicon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                    
                    Text("TanyaLe")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.brandOrange, .brandPurple],
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
                    // Create New Journey — pushed as a page, not a sheet.
                    NavigationLink {
                        JourneySetupView()
                    } label: {
                        HStack {
                            Text("Create New Journey")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient.brandPurpleButton(), in: Capsule())
                        .foregroundColor(.white)
                    }
                    
                    // View Past Journeys Button
                    Button {
                        showPastJourneys = true
                    } label: {
                        HStack {
                            Text("View Past Journeys")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white, in: Capsule())
                        .foregroundStyle(LinearGradient.brandPurpleButton())
                        .overlay(
                            Capsule()
                                .stroke(LinearGradient.brandPurpleButton(), lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 60)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPastJourneys) {
            PastJourneysListView()
        }
    }
}

#Preview {
    JourneyLandingView()
}
