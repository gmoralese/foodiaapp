import AVFoundation
import UIKit

/// Dueño de la sesión AVFoundation. Vive fuera del MainActor: todo el trabajo
/// de sesión pasa por su cola serial (disciplina de @unchecked Sendable).
nonisolated final class CameraService: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "foodia.camera")
    private let output = AVCapturePhotoOutput()
    private var position: AVCaptureDevice.Position = .back
    private var flashOn = false
    private var captureHandler: (@Sendable (UIImage?) -> Void)?

    static var isCameraAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func configureAndStart() {
        queue.async { [self] in
            guard session.inputs.isEmpty else {
                if !session.isRunning { session.startRunning() }
                return
            }
            session.beginConfiguration()
            session.sessionPreset = .photo
            attachInput(position: position)
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func setFlash(_ on: Bool) {
        queue.async { [self] in flashOn = on }
    }

    func flip() {
        queue.async { [self] in
            position = position == .back ? .front : .back
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            attachInput(position: position)
            session.commitConfiguration()
        }
    }

    func capture(_ handler: @escaping @Sendable (UIImage?) -> Void) {
        queue.async { [self] in
            captureHandler = handler
            let settings = AVCapturePhotoSettings()
            if output.supportedFlashModes.contains(.on) {
                settings.flashMode = flashOn ? .on : .off
            }
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    private func attachInput(position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        captureHandler?(image)
        captureHandler = nil
    }
}
