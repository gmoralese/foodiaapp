import AVFoundation
import PhotosUI
import SwiftUI

/// Cámara full-screen del diseño. Estados: activa · analizando ·
/// error de análisis · sin permiso. Siempre oscura.
struct CameraScreen: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: (String) -> Void

    @State private var camera = CameraService()
    @State private var permissionDenied = false
    @State private var flashOn = false
    @State private var photosItem: PhotosPickerItem?
    @State private var model: AnalysisModel?
    @State private var analysisTask: Task<Void, Never>?
    @State private var showResumen = false
    @State private var showDescribe = false

    private var cameraUsable: Bool {
        CameraService.isCameraAvailable && !permissionDenied
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let model {
                analysisOverlay(model)
            } else if cameraUsable {
                liveCamera
            } else {
                deniedView
            }
        }
        .preferredColorScheme(.dark)
        .task { await requestPermission() }
        .onDisappear { camera.stop() }
        .onChange(of: photosItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    begin(with: image)
                }
                photosItem = nil
            }
        }
        .sheet(isPresented: $showDescribe) {
            DescribeMealSheet { description in
                showDescribe = false
                let analysisModel = AnalysisModel(description: description)
                model = analysisModel
                runAnalysis { await analysisModel.analyze() }
            }
        }
        .sheet(isPresented: $showResumen, onDismiss: { model = nil }) {
            if let model {
                NavigationStack {
                    AnalysisView(model: model) {
                        onSaved(String(localized: "Comida guardada"))
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: Cámara activa

    private var liveCamera: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
            reticle
            VStack {
                HStack {
                    glassButton("xmark") { dismiss() }
                    Spacer()
                    glassButton(flashOn ? "bolt.fill" : "bolt.slash") {
                        flashOn.toggle()
                        camera.setFlash(flashOn)
                    }
                }
                .padding(.horizontal, 20)
                Spacer()
                Text("Encuadra el plato completo, con buena luz")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: .capsule)
                    .padding(.bottom, 8)
                Button {
                    showDescribe = true
                } label: {
                    Label("O descríbela sin foto", systemImage: "text.bubble")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(.white.opacity(0.14), in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 14)
                controls
            }
        }
    }

    private var controls: some View {
        HStack {
            PhotosPicker(selection: $photosItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.12), in: .rect(cornerRadius: DSRadius.thumb, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DSRadius.thumb, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    }
            }
            .accessibilityLabel("Elegir de la galería")
            Spacer()
            Button {
                camera.capture { image in
                    Task { @MainActor in
                        if let image { begin(with: image) }
                    }
                }
            } label: {
                ZStack {
                    Circle().strokeBorder(.white, lineWidth: 4).frame(width: 78, height: 78)
                    Circle().fill(.white).frame(width: 62, height: 62)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tomar foto")
            Spacer()
            Button {
                camera.flip()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.12), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Girar cámara")
        }
        .padding(.horizontal, 34)
        .padding(.bottom, 24)
    }

    private var reticle: some View {
        ReticleShape()
            .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 280, height: 280)
    }

    // MARK: Analizando / error

    @ViewBuilder
    private func analysisOverlay(_ model: AnalysisModel) -> some View {
        ZStack {
            if let image = model.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(.black.opacity(0.55))
            }
            if case .failed(let message) = model.phase {
                errorCard(message: message, model: model)
            } else {
                analyzingCard(model)
            }
        }
    }

    private func analyzingCard(_ model: AnalysisModel) -> some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.dsAccent)
                    Text(model.phase == .preparingModel ? "Preparando el motor…" : "Detectando alimentos…")
                        .font(.dsSection)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 8) {
                    checklistRow("Foto lista", state: .done)
                    checklistRow("Detectando alimentos", state: .active)
                    checklistRow("Calculando macros", state: .pending)
                }
                Label(engineChipText, systemImage: EnginePreference.current == .cloud ? "cloud.fill" : "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.1), in: .capsule)
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(.black.opacity(0.72), in: .rect(cornerRadius: 24, style: .continuous))
            Spacer()
            Button("Cancelar") {
                analysisTask?.cancel()
                self.model = nil
            }
            .font(.dsButton)
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
            .frame(minHeight: 46)
            .background(.white.opacity(0.14), in: .capsule)
            .padding(.bottom, 30)
        }
    }

    private var engineChipText: String {
        switch EnginePreference.current {
        case .cloud: String(localized: "Motor Nube · máxima precisión")
        case .local, .auto: String(localized: "Motor Local · sin salir de tu iPhone")
        }
    }

    private enum StepState { case done, active, pending }

    private func checklistRow(_ title: LocalizedStringKey, state: StepState) -> some View {
        HStack(spacing: 8) {
            switch state {
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.dsAccent)
            case .active:
                Image(systemName: "circle.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 9))
                    .frame(width: 17)
            case .pending:
                Image(systemName: "circle")
                    .foregroundStyle(.white.opacity(0.35))
            }
            Text(title)
                .font(.subheadline.weight(state == .active ? .bold : .regular))
                .foregroundStyle(state == .pending ? .white.opacity(0.45) : .white)
        }
    }

    private func errorCard(message: String, model: AnalysisModel) -> some View {
        VStack(spacing: 14) {
            DSIcon(id: "wifi-off", size: 40, tint: .white.opacity(0.8))
            Text("Se cortó la conexión")
                .font(.dsSection)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Button {
                runAnalysis { await model.analyzeWithLocalEngine() }
            } label: {
                Label("Analizar con Local", systemImage: "lock.fill")
            }
            .buttonStyle(.dsPrimary)
            Button("Reintentar con Nube") {
                runAnalysis { await model.analyze() }
            }
            .font(.dsButton)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(.white.opacity(0.12), in: .rect(cornerRadius: DSRadius.row, style: .continuous))
            Button("Cargar la comida a mano") {
                showResumen = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(22)
        .frame(maxWidth: 330)
        .background(.black.opacity(0.72), in: .rect(cornerRadius: 24, style: .continuous))
    }

    // MARK: Sin permiso

    private var deniedView: some View {
        VStack(spacing: 14) {
            DSIcon(id: "camera-off", size: 44, tint: .white.opacity(0.8))
            Text("Foodia no puede ver tu plato")
                .font(.dsSection)
                .foregroundStyle(.white)
            Text(CameraService.isCameraAvailable
                ? "Le negaste el acceso a la cámara (todo bien). Para sacar fotos, actívalo en Ajustes → Foodia → Cámara."
                : "Este equipo no tiene cámara disponible. Puedes elegir una foto de la galería.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            if CameraService.isCameraAvailable {
                Button("Abrir Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.dsPrimary)
            }
            PhotosPicker(selection: $photosItem, matching: .images) {
                Text("Elegir de la galería")
                    .font(.dsButton)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.white.opacity(0.12), in: .rect(cornerRadius: DSRadius.row, style: .continuous))
            }
        }
        .padding(24)
        .frame(maxWidth: 340)
        .overlay(alignment: .topLeading) {
            glassButton("xmark") { dismiss() }
                .offset(x: -100, y: -180)
        }
    }

    // MARK: Flujo

    private func begin(with image: UIImage) {
        let analysisModel = AnalysisModel(image: image)
        model = analysisModel
        runAnalysis { await analysisModel.analyze() }
    }

    private func runAnalysis(_ operation: @escaping () async -> Void) {
        analysisTask = Task {
            await operation()
            guard !Task.isCancelled, let model else { return }
            if model.phase == .done {
                showResumen = true
            }
        }
    }

    private func requestPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            camera.configureAndStart()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionDenied = !granted
            if granted { camera.configureAndStart() }
        default:
            permissionDenied = true
        }
    }

    private func glassButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.5), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

/// Preview de la sesión de captura.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Retícula de encuadre: 4 esquinas.
private struct ReticleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let arm: CGFloat = 30
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY + arm), CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + arm, y: rect.minY)),
            (CGPoint(x: rect.maxX - arm, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + arm)),
            (CGPoint(x: rect.maxX, y: rect.maxY - arm), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX - arm, y: rect.maxY)),
            (CGPoint(x: rect.minX + arm, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY - arm)),
        ]
        for (start, corner, end) in corners {
            path.move(to: start)
            path.addLine(to: corner)
            path.addLine(to: end)
        }
        return path
    }
}
