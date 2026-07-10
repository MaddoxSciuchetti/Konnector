@preconcurrency import AVFoundation
import AudioToolbox
import SwiftUI

struct QRCodeScannerView: View {
    let onCodeScanned: (String) -> Void
    let onCancel: () -> Void

    @State private var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            Group {
                switch authorizationStatus {
                case .authorized:
                    QRCodeScannerRepresentable(onCodeScanned: onCodeScanned)
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(alignment: .center) {
                            scannerFrame
                        }
                case .notDetermined:
                    ProgressView()
                        .task { await requestCameraAccess() }
                case .denied, .restricted:
                    ContentUnavailableView {
                        Label("Camera Access Needed", systemImage: "camera")
                    } description: {
                        Text("Allow camera access in Settings to scan a LinkedIn QR code.")
                    }
                @unknown default:
                    ContentUnavailableView("Camera Unavailable", systemImage: "camera")
                }
            }
            .navigationTitle("Scan LinkedIn QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private var scannerFrame: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(.white, lineWidth: 3)
            .frame(width: 230, height: 230)
            .shadow(radius: 8)
            .accessibilityHidden(true)
    }

    @MainActor
    private func requestCameraAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = granted ? .authorized : AVCaptureDevice.authorizationStatus(for: .video)
    }
}

private struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let controller = QRCodeScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {
        uiViewController.onCodeScanned = onCodeScanned
    }
}

private final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScanCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        didScanCode = false
        startSessionIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSessionIfNeeded()
    }

    private func configureCaptureSession() {
        guard let captureDevice = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: captureDevice),
              captureSession.canAddInput(input)
        else {
            return
        }

        captureSession.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else { return }

        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
    }

    private func startSessionIfNeeded() {
        guard !captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.startRunning()
        }
    }

    private func stopSessionIfNeeded() {
        guard captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.stopRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScanCode,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = metadataObject.stringValue
        else {
            return
        }

        didScanCode = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onCodeScanned?(value)
    }
}
