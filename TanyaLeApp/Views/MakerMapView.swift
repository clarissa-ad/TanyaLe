import SwiftUI
import MapKit

struct MakerMapView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = MakerViewModel()
    
    // Default region for map
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: viewModel.checkpoints) { checkpoint in
                MapAnnotation(coordinate: checkpoint.coordinate) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.purple)
                        Text(checkpoint.title)
                            .font(.caption)
                            .bold()
                            .padding(4)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onReceive(locationManager.$userLocation) { location in
                guard let location = location else { return }
                region.center = location.coordinate
            }
            
            VStack {
                Text("Maker: 2D Minimap")
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top, 40)
                Spacer()
                
                Button(action: {
                    // For the 2D map, if they tap this, we simulate an AR transform of (0,0,0) just for data completeness.
                    if let location = locationManager.userLocation {
                        viewModel.addCheckpointAt(
                            transform: SIMD3<Float>(0, 0, 0),
                            title: "2D Map Point",
                            description: "Dropped from map",
                            overrideLocation: location.coordinate
                        )
                    }
                }) {
                    Text("Drop Checkpoint Here")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .padding(20)
                .disabled(locationManager.userLocation == nil)
                .opacity(locationManager.userLocation == nil ? 0.5 : 1.0)
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }
}
