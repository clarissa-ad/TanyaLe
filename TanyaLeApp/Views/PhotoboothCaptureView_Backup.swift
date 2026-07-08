import SwiftUI
import AVFoundation

struct PhotoboothCaptureView_Backup: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var cameraManager = CameraManager()
    let checkpoint: Checkpoint
    var onImageCaptured: ((UIImage) -> Void)?
    
    @State private var currentZoomFactor: CGFloat = 1.0
    @State private var isCapturing = false
    
    var body: some View {
        ZStack {
            // Live Camera Feed
            if cameraManager.permissionGranted || cameraManager.errorMsg != nil {
                if let error = cameraManager.errorMsg {
                    Color.black.ignoresSafeArea()
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    CameraPreviewView(cameraManager: cameraManager)
                        .ignoresSafeArea()
                        .gesture(
                            MagnificationGesture()
                                .onChanged { val in
                                    cameraManager.setZoom(factor: currentZoomFactor * val)
                                }
                                .onEnded { val in
                                    currentZoomFactor = max(1.0, currentZoomFactor * val)
                                }
                        )
                }
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Camera permission required.")
                        .foregroundColor(.white)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            // Dimmed overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack {
                // Top Bar with Controls
                HStack {
                    // Flash Button
                    Button(action: {
                        switch cameraManager.flashMode {
                        case .off: cameraManager.flashMode = .on
                        case .on: cameraManager.flashMode = .auto
                        case .auto: cameraManager.flashMode = .off
                        @unknown default: cameraManager.flashMode = .off
                        }
                    }) {
                        Image(systemName: cameraManager.flashMode == .on ? "bolt.fill" : (cameraManager.flashMode == .auto ? "bolt.badge.a.fill" : "bolt.slash.fill"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Flip Button
                    Button(action: {
                        cameraManager.switchCamera()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Close Button
                    Button(action: {
                        cameraManager.stop()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal)
                
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
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .clipped()
                    }
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 32)
                .shadow(radius: 20)
                
                Spacer()
                
                // Shutter Button
                Button(action: {
                    isCapturing = true
                    cameraManager.capturePhoto()
                }) {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                        .background(Color.white.opacity(0.3).clipShape(Circle()))
                }
                .disabled(isCapturing)
                .opacity(isCapturing ? 0.5 : 1.0)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: cameraManager.capturedImage) { _, image in
            if let image = image {
                cameraManager.stop()
                onImageCaptured?(image)
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onDisappear {
            cameraManager.stop()
        }
    }
}
