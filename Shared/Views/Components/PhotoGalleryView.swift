import SwiftUI

struct PhotoGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    var photoService = MockPhotoService.shared
    let checkpoint: Checkpoint
    
    var body: some View {
        NavigationView {
            ScrollView {
                let photos = photoService.fetchPhotos(forCheckpoint: checkpoint.id)
                if photos.isEmpty {
                    VStack {
                        Spacer(minLength: 100)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No photos yet!")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.top)
                        Text("Be the first to snap a photo at this location.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                        ForEach(0..<photos.count, id: \.self) { index in
                            Image(uiImage: photos[index])
                                .resizable()
                                .scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 4)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Photo Gallery")
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
