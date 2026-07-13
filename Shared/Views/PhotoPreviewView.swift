import SwiftUI
import UIKit

struct PhotoPreviewView: View {
    let checkpoint: Checkpoint
    
    var onRetake: () -> Void
    var onExploreMore: (UIImage) -> Void
    
    @State private var currentImage: UIImage
    
    init(capturedImage: UIImage, checkpoint: Checkpoint, onRetake: @escaping () -> Void, onExploreMore: @escaping (UIImage) -> Void) {
        self.checkpoint = checkpoint
        self.onRetake = onRetake
        self.onExploreMore = onExploreMore
        self._currentImage = State(initialValue: capturedImage)
    }
    
    // Randomize layout once on init
    @State private var scatteredPhotos: [ScatteredPhoto] = []
    
    struct ScatteredPhoto: Identifiable {
        let id = UUID()
        let image: UIImage
        let xOffset: CGFloat
        let yOffset: CGFloat
        let rotation: Double
        let scale: CGFloat
    }

    var body: some View {
        ZStack {
            // Dark background (can be somewhat transparent if overlaid over camera,
            // but we'll use a solid dark gray/black to match the reference)
            Color(white: 0.15)
                .ignoresSafeArea()
            
            // ── Background Scattered Photos (Parallax/3D effect) ──
            ForEach(scatteredPhotos) { photo in
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white, lineWidth: 6)
                    )
                    .rotationEffect(.degrees(photo.rotation))
                    .scaleEffect(photo.scale)
                    .offset(x: photo.xOffset, y: photo.yOffset)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 5, y: 10)
            }
            
            // ── Foreground Prompt Card ──
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thank you for filling!")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    
                    Text(checkpoint.question.isEmpty ? "Take a selfie that captures your first reaction to this place." : checkpoint.question)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // The newly captured photo with a rotation button overlay
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: currentImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .clipped()
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        rotateImage()
                    }) {
                        Image(systemName: "rotate.right.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(12)
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: onRetake) {
                        Text("Retake")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color(white: 0.9))
                            .cornerRadius(20)
                    }
                    
                    Button(action: {
                        onExploreMore(currentImage)
                    }) {
                        Text("Explore more")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(24)
            .padding(.horizontal, 32)
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            
        }
        .onAppear {
            generateScatteredLayout()
        }
    }
    
    private func rotateImage() {
        guard let cgImage = currentImage.cgImage else { return }
        
        let newOrientation: UIImage.Orientation
        switch currentImage.imageOrientation {
        case .up: newOrientation = .right
        case .right: newOrientation = .down
        case .down: newOrientation = .left
        case .left: newOrientation = .up
        case .upMirrored: newOrientation = .rightMirrored
        case .rightMirrored: newOrientation = .downMirrored
        case .downMirrored: newOrientation = .leftMirrored
        case .leftMirrored: newOrientation = .upMirrored
        @unknown default: newOrientation = .right
        }
        
        currentImage = UIImage(cgImage: cgImage, scale: currentImage.scale, orientation: newOrientation)
    }
    
    private func generateScatteredLayout() {
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        let captured = currentImage
        
        Task.detached {
            // Resize image to a thumbnail in background to prevent memory bloat and UI freeze
            let ratio = captured.size.height / max(captured.size.width, 1)
            let targetSize = CGSize(width: 300, height: 300 * ratio)
            let thumbnail = captured.preparingThumbnail(of: targetSize) ?? captured
            
            var newPhotos: [ScatteredPhoto] = []
            
            for i in 0..<5 {
                // Distribute them around the edges (avoiding the exact center)
                let isLeft = (i % 2 == 0)
                let minX: CGFloat = isLeft ? -screenW/2 : screenW/4
                let maxX: CGFloat = isLeft ? -screenW/4 : screenW/2
                let xOffset = CGFloat.random(in: minX...maxX)
                let yOffset = CGFloat.random(in: -screenH/3 ... screenH/3)
                let rot     = Double.random(in: -25...25)
                let scale   = CGFloat.random(in: 0.8...1.1)
                
                newPhotos.append(ScatteredPhoto(
                    image: thumbnail,
                    xOffset: xOffset,
                    yOffset: yOffset,
                    rotation: rot,
                    scale: scale
                ))
            }
            
            await MainActor.run {
                self.scatteredPhotos = newPhotos
            }
        }
    }
}

#Preview {
    PhotoPreviewView(
        capturedImage: UIImage(systemName: "photo")!,
        checkpoint: Checkpoint(
            title: "Test",
            taskDescription: "Test Desc",
            interactionType: .photobooth,
            question: "Take a selfie that captures your first reaction to this place.",
            surveyOptions: [],
            emojiLeft: "",
            emojiRight: "",
            promptPhotoID: nil,
            latitude: 0.0,
            longitude: 0.0,
            relativeX: 0,
            relativeY: 0,
            relativeZ: 0
        ),
        onRetake: {},
        onExploreMore: { _ in }
    )
}
