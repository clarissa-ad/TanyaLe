import SwiftUI
import MapKit

struct UserMinimapView: View {
    @State private var locationManager = LocationManager()
    private var db = MockDatabaseService.shared
    
    /// Default map zoom level.
    private let mapSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    @State private var mapPosition = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))

    @State private var selectedCheckpoint: Checkpoint?

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapPosition) {
                UserAnnotation()

                ForEach(db.checkpoints) { checkpoint in
                    Annotation("", coordinate: checkpoint.coordinate) {
                        Button(action: {
                            selectedCheckpoint = checkpoint
                        }) {
                            VStack {
                                Image(systemName: "mappin.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(.green)
                                Text(checkpoint.title)
                                    .font(.caption)
                                    .bold()
                                    .padding(4)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .onChange(of: locationManager.userLocation) { _, location in
                guard let location = location else { return }
                mapPosition = .region(MKCoordinateRegion(center: location.coordinate, span: mapSpan))
            }
            
            VStack {
                Text("Citizen: 2D Minimap")
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                    .padding(.top, 40)
                Spacer()
                
                if let cp = selectedCheckpoint {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("📍 \(cp.title)")
                                .font(.title2)
                                .bold()
                            Spacer()
                            Button(action: { selectedCheckpoint = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                            }
                        }
                        Text(cp.taskDescription)
                            .font(.body)
                        
                        Button(action: {
                            // Close popup
                            selectedCheckpoint = nil
                        }) {
                            Text("Close")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 20)
                    .padding(20)
                    .transition(.move(edge: .bottom))
                    .animation(.spring(), value: selectedCheckpoint != nil)
                }
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }
}
