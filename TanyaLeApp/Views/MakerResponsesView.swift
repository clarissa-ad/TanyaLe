import SwiftUI

struct MakerResponsesView: View {
    let checkpoint: Checkpoint
    var photoService = MockPhotoService.shared
    
    // We can also inject DatabaseService here if we want to show MCQ answers,
    // but for now, this focuses on the photobooth gallery.
    
    var body: some View {
        ScrollView {
            let photos = photoService.fetchPhotos(forCheckpoint: checkpoint.id)
            if photos.isEmpty {
                VStack {
                    Spacer(minLength: 100)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No photos submitted yet.")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.top)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    ForEach(0..<photos.count, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: photos[index])
                                .resizable()
                                .scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 4)
                            
                            Button(action: {
                                photoService.deletePhoto(image: photos[index], forCheckpoint: checkpoint.id)
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.red)
                                    .background(Color.white.clipShape(Circle()))
                                    .padding(8)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Responses")
    }
}
