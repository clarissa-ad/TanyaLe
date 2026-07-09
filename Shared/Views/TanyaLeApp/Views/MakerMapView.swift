import SwiftUI
import MapKit

struct MakerMapView: View {
    private var locationManager = LocationManager.shared
    @State private var viewModel = MakerViewModel()
    
    /// Default map zoom level.
    private let mapSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    @State private var mapPosition = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapPosition) {
                UserAnnotation()

                ForEach(viewModel.checkpoints) { checkpoint in
                    Annotation("", coordinate: checkpoint.coordinate) {
                        VStack {
                            Image(systemName: "mappin.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.purple)
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
            .ignoresSafeArea()
            .onChange(of: locationManager.userLocation) { _, location in
                guard let location = location else { return }
                mapPosition = .region(MKCoordinateRegion(center: location.coordinate, span: mapSpan))
            }
            
            VStack {
                Text("Maker: 2D Minimap")
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                    .padding(.top, 40)
                Spacer()
                
                Button(action: {
                    // For the 2D map, if they tap this, we simulate an AR transform of (0,0,0) just for data completeness.
//                    if let location = locationManager.userLocation {
//                        viewModel.addCheckpointAt(
//                            transform: SIMD3<Float>(0, 0, 0),
//                            title: "2D Map Point",
//                            description: "Dropped from map",
//                            overrideLocation: location.coordinate
//                        )
//                    }
                }) {
                    Text("Drop Checkpoint Here")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundStyle(.white)
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
