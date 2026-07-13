import SwiftUI
import UIKit

/// A robust, native camera view that uses Apple's highly-optimized UIImagePickerController
/// while safely overlaying the custom Figma prompt card in a way that doesn't block controls.
struct PhotoboothCaptureView: View {
    @Environment(\.presentationMode) private var presentationMode
    let checkpoint: Checkpoint
    var onImageCaptured: ((UIImage) -> Void)?
    
    var body: some View {
        ZStack(alignment: .top) {
            // Native Camera
            NativeCameraPicker(onImageCaptured: { image in
                onImageCaptured?(image)
                presentationMode.wrappedValue.dismiss()
            }, onDismiss: {
                presentationMode.wrappedValue.dismiss()
            })
            .ignoresSafeArea()
            
            // Dimmed overlay background for the card
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .allowsHitTesting(false) // Let touches pass through to the native camera controls
            
            // Prompt Card
            VStack(alignment: .leading, spacing: 16) {
                Text(checkpoint.question.isEmpty ? "Take a selfie that captures your first reaction to this place." : checkpoint.question)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let id = checkpoint.promptPhotoID, let image = MockPhotoService.shared.fetchPromptPhoto(id: id) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180) // Slightly smaller so it doesn't block native UI
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .clipped()
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(24)
            .padding(.horizontal, 24)
            .padding(.top, 60) // Push it down below the native top controls (Flash, timer, etc)
            .shadow(radius: 10)
            .allowsHitTesting(false) // Let touches pass through
        }
    }
}

struct NativeCameraPicker: UIViewControllerRepresentable {
    var onImageCaptured: ((UIImage) -> Void)?
    var onDismiss: (() -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraDevice = .front
            picker.showsCameraControls = true // Native robust controls (Flash, Flip, Zoom, Shutter, Cancel)
            picker.allowsEditing = true // Allows native crop/rotate after capture
        } else {
            // Fallback for Simulator
            picker.sourceType = .photoLibrary
        }
        
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: NativeCameraPicker
        
        init(_ parent: NativeCameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Use edited image if available (user cropped/rotated), else original
            let capturedImage = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            
            guard let image = capturedImage else {
                parent.onDismiss?()
                return
            }
            
            // Downsample the massive 12MP camera image in the background to prevent Main Thread freeze
            Task.detached {
                let maxDimension: CGFloat = 1500
                let ratio = image.size.height / max(image.size.width, 1)
                
                let targetSize: CGSize
                if image.size.width > image.size.height {
                    targetSize = CGSize(width: maxDimension, height: maxDimension * ratio)
                } else {
                    targetSize = CGSize(width: maxDimension / ratio, height: maxDimension)
                }
                
                // preparingThumbnail is heavily optimized by CoreGraphics and drops memory from ~48MB to ~5MB
                let optimizedImage = image.preparingThumbnail(of: targetSize) ?? image
                
                await MainActor.run {
                    self.parent.onImageCaptured?(optimizedImage)
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss?()
        }
    }
}
