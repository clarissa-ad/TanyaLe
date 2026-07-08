import SwiftUI
import AVFoundation
import Observation

@Observable
class CameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    var session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera_queue")
    
    var capturedImage: UIImage? = nil
    var permissionGranted = false
    var errorMsg: String? = nil
    
    var flashMode: AVCaptureDevice.FlashMode = .off
    var position: AVCaptureDevice.Position = .front
    
    private var activeInput: AVCaptureDeviceInput?
    private var activeDevice: AVCaptureDevice?
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.permissionGranted = true
            sessionQueue.async {
                self.setupCamera()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.sessionQueue.async {
                            self?.setupCamera()
                        }
                    }
                }
            }
        case .denied, .restricted:
            permissionGranted = false
        @unknown default:
            permissionGranted = false
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            DispatchQueue.main.async {
                self.errorMsg = "No camera found (Are you on the Simulator?)"
            }
            session.commitConfiguration()
            return
        }
        activeDevice = device
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                activeInput = input
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        session.commitConfiguration()
        
        if !session.isRunning {
            session.startRunning()
        }
    }
    
    func switchCamera() {
        sessionQueue.async {
            self.position = self.position == .back ? .front : .back
            
            self.session.beginConfiguration()
            
            // Remove existing input
            if let activeInput = self.activeInput {
                self.session.removeInput(activeInput)
            }
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.position) else {
                self.session.commitConfiguration()
                return
            }
            self.activeDevice = newDevice
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.activeInput = newInput
                }
            } catch {
                print(error.localizedDescription)
            }
            
            self.session.commitConfiguration()
        }
    }
    
    func setZoom(factor: CGFloat) {
        sessionQueue.async {
            guard let device = self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
                device.unlockForConfiguration()
            } catch {
                print("Failed to lock device for zoom: \(error)")
            }
        }
    }
    
    func capturePhoto() {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            if self.output.supportedFlashModes.contains(self.flashMode) {
                settings.flashMode = self.flashMode
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        if let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.capturedImage = image
            }
        }
    }
    
    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreviewView: UIViewRepresentable {
    var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = cameraManager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
