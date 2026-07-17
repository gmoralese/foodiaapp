import SwiftUI

/// Cover de captura: cámara full-screen → análisis → Resumen.
struct CaptureFlowView: View {
    @Environment(\.dismiss) private var dismiss
    /// Se invoca al guardar una comida, con el mensaje del toast.
    var onSaved: (String) -> Void

    var body: some View {
        CameraScreen(onSaved: onSaved)
    }
}
