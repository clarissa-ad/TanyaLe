import SwiftUI
import MapKit

struct UserMinimapView: View {
    @StateObject private var locationManager = LocationManager()
    @ObservedObject private var db = MockDatabaseService.shared
    
    // Default region
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var selectedCheckpoint: Checkpoint?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // The Map
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: db.checkpoints) { checkpoint in
                MapAnnotation(coordinate: checkpoint.coordinate) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.purple)
                            .onTapGesture {
                                selectedCheckpoint = checkpoint
                            }
                        
                        Text(checkpoint.title)
                            .font(.caption)
                            .bold()
                            .padding(4)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
            }
            .ignoresSafeArea()
            .onReceive(locationManager.$userLocation) { location in
                if let location = location {
                    // Smoothly follow the user like a GTA map
                    withAnimation {
                        region.center = location.coordinate
                    }
                }
            }
            .onAppear {
                locationManager.requestPermission()
            }
            
            // Pop-up Card when a checkpoint is tapped
            if let selected = selectedCheckpoint {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selected.title)
                        .font(.headline)
                    Text(selected.taskDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Dismiss") {
                        selectedCheckpoint = nil
                    }
                    .padding(.top, 4)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding()
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: selectedCheckpoint)
            }
        }
        .navigationTitle("Citizen Minimap")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    UserMinimapView()
}
