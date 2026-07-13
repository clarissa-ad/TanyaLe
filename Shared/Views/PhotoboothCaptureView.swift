import SwiftUI
import AVFoundation
import Combine

/// A native custom AVFoundation camera view embedded directly inside the prompt card.
struct PhotoboothCaptureView: View {
    let checkpoint: Checkpoint
    var onImageCaptured: (UIImage) -> Void
    var onCancel: () -> Void
    
    @StateObject private var cameraService = CameraService()
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            
            VStack {
                // Top controls
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 50)
                
                Spacer()
                
                // Prompt Card
                VStack(alignment: .leading, spacing: 16) {
                    Text(checkpoint.question.isEmpty ? "Take a selfie that captures your first reaction to this place." : checkpoint.question)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Live Camera Viewfinder (same dimensions as PhotoPreviewView)
                    ZStack(alignment: .bottomTrailing) {
                        AVCameraPreviewView(session: cameraService.session)
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .clipped()
                        
                        // Flip Camera Button
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            cameraService.flipCamera()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(12)
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 24)
                .shadow(radius: 10)
                
                Spacer()
                
                // Shutter Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    let cardWidth = UIScreen.main.bounds.width - 48 - 40 // Screen minus padding
                    let targetRatio = cardWidth / 300.0
                    
                    cameraService.capturePhoto { image in
                        let cropped = image.cropping(toAspectRatio: targetRatio)
                        onImageCaptured(cropped)
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 76, height: 76)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 64, height: 64)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onDisappear {
            cameraService.stop()
        }
    }
}

class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var isFrontCamera = true // Selfies are default for photobooths
    private let output = AVCapturePhotoOutput()
    private var onCapture: ((UIImage) -> Void)?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func stop() {
        DispatchQueue.global(qos: .background).async {
            self.session.stopRunning()
        }
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    func setupCamera() {
        DispatchQueue.global(qos: .background).async {
            self.session.beginConfiguration()
            
            // Remove existing inputs
            for oldInput in self.session.inputs {
                self.session.removeInput(oldInput)
            }
            
            let position: AVCaptureDevice.Position = self.isFrontCamera ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            if !self.session.outputs.contains(self.output) {
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    
    func flipCamera() {
        isFrontCamera.toggle()
        setupCamera()
    }
    
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        self.onCapture = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        
        // Correct orientation for front camera so it doesn't mirror backwards when saved
        let finalImage: UIImage
        if isFrontCamera, let cgImage = image.cgImage {
            // iOS front camera returns raw flipped images. This corrects it.
            finalImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
        } else {
            finalImage = image
        }
        
        DispatchQueue.main.async {
            self.onCapture?(finalImage)
        }
    }
}

struct AVCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

extension UIImage {
    /// Crops the image from the center to match a specific aspect ratio
    func cropping(toAspectRatio targetRatio: CGFloat) -> UIImage {
        // CoreGraphics operates on unoriented pixel dimensions
        let rawWidth = CGFloat(cgImage?.width ?? Int(size.width))
        let rawHeight = CGFloat(cgImage?.height ?? Int(size.height))
        
        let originalRatio = rawWidth / rawHeight
        var cropRect: CGRect
        
        if originalRatio > targetRatio {
            // Image is too wide, crop left/right
            let newWidth = rawHeight * targetRatio
            cropRect = CGRect(x: (rawWidth - newWidth) / 2, y: 0, width: newWidth, height: rawHeight)
        } else {
            // Image is too tall, crop top/bottom
            let newHeight = rawWidth / targetRatio
            cropRect = CGRect(x: 0, y: (rawHeight - newHeight) / 2, width: rawWidth, height: newHeight)
        }
        
        guard let croppedCgImage = cgImage?.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: croppedCgImage, scale: scale, orientation: imageOrientation)
    }
}
