import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

/// 扫描页的取景。真机用摄像头；模拟器没有镜头时，用示例名片当取景画面。
struct ScanCameraScreen: View {
    @Binding var pickerItem: PhotosPickerItem?
    var onCapture: (UIImage) -> Void
    var onClose: () -> Void

    @State private var phase: Phase = .checking
    @State private var sampleIndex = 0
    @State private var lit = false
    @StateObject private var camera = LiveCameraModel()
    private let samples = SimulatorCameraSamples.load()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            preview
            chrome
        }
        .task {
            phase = await CameraAccess.resolve()
            if phase == .live {
                camera.start()
            }
        }
        .onDisappear {
            camera.stop()
            camera.setTorch(false)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch phase {
        case .checking:
            ProgressView()
                .tint(.white)
        case .live:
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
        case .simulated:
            simulatedPreview
        case .denied:
            deniedPrompt
        }
    }

    private var simulatedPreview: some View {
        ZStack {
            Color(white: 0.82).ignoresSafeArea()
            if samples.indices.contains(sampleIndex) {
                Image(uiImage: samples[sampleIndex])
                    .resizable()
                    .scaledToFit()
                    .padding(48)
                    .brightness(lit ? 0.18 : 0)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard !samples.isEmpty else { return }
                    if value.translation.width < -30 {
                        sampleIndex = (sampleIndex + 1) % samples.count
                    } else if value.translation.width > 30 {
                        sampleIndex = (sampleIndex - 1 + samples.count) % samples.count
                    }
                }
        )
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("关闭")
                Spacer()
            }
            .padding(.horizontal, 8)

            Spacer()

            if phase == .live || phase == .simulated {
                viewfinder
                    .padding(.horizontal, 28)
                Spacer()
                bottomBar
            } else {
                Spacer()
            }
        }
    }

    private var viewfinder: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.92), lineWidth: 1.5)
            VStack(spacing: 18) {
                Text("正在寻找名片边框")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.16, green: 0.56, blue: 0.98), in: RoundedRectangle(cornerRadius: 4))
                Button {
                    lit.toggle()
                    if phase == .live {
                        camera.setTorch(lit)
                    }
                } label: {
                    Label("轻触照亮", systemImage: lit ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.45), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.70, contentMode: .fit)
    }

    private var bottomBar: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("从相册导入")
            Spacer()
            Button(action: shutter) {
                Circle()
                    .fill(Color.white)
                    .padding(5)
                    .background {
                        Circle().stroke(Color(red: 0.20, green: 0.55, blue: 0.98), lineWidth: 4)
                    }
                    .frame(width: 74, height: 74)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("拍摄")
            Spacer()
            Color.clear
                .frame(width: 48, height: 48)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }

    private var deniedPrompt: some View {
        VStack(spacing: 16) {
            Text("需要相机权限才能拍摄名片")
                .font(.headline)
                .foregroundStyle(.white)
            Button("去设置") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("从相册导入")
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .padding()
    }

    private func shutter() {
        switch phase {
        case .live:
            camera.onPhoto = onCapture
            camera.capture()
        case .simulated:
            guard samples.indices.contains(sampleIndex) else { return }
            onCapture(samples[sampleIndex])
        case .checking, .denied:
            break
        }
    }
}

private enum Phase {
    case checking
    case live
    case simulated
    case denied
}

private enum CameraAccess {
    static func resolve() async -> Phase {
        guard AVCaptureDevice.default(for: .video) != nil else {
            return .simulated
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .live
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .live : .denied
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }
}

private enum SimulatorCameraSamples {
    static func load() -> [UIImage] {
        ["C001", "C013", "C015"].compactMap { name in
            let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "SimulatorCamera")
                ?? Bundle.main.url(forResource: name, withExtension: "png")
            guard let url, let image = UIImage(contentsOfFile: url.path) else { return nil }
            return image
        }
    }
}

private final class LiveCameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    var onPhoto: ((UIImage) -> Void)?
    private let output = AVCapturePhotoOutput()
    private var configured = false
    private var device: AVCaptureDevice?

    func start() {
        if !configured {
            configure()
        }
        guard configured, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            return
        }
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async {
            self.onPhoto?(image)
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        guard let camera,
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input),
              session.canAddOutput(output) else {
            return
        }
        device = camera
        session.addInput(input)
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        configured = true
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let connection = uiView.previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
