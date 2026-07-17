import SwiftUI

/// Registro sin foto: el usuario describe la comida (escrita o dictada)
/// y la IA estima los componentes con porciones típicas.
struct DescribeMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var dictation = SpeechDictation()
    var onSubmit: (String) -> Void

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Cuéntanos qué comiste — con cantidades si las sabes — y la IA estima los macros.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
                HStack(alignment: .top, spacing: 8) {
                    TextField(
                        "Ej.: 2 huevos revueltos con una arepa y jugo de naranja",
                        text: $text,
                        axis: .vertical
                    )
                    .font(.body)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DSRadius.row, style: .continuous)
                            .strokeBorder(
                                dictation.state == .recording ? Color.dsAccent : .dsHairline,
                                lineWidth: dictation.state == .recording ? 1.5 : 1
                            )
                    }
                    Button {
                        dictation.toggle()
                    } label: {
                        Image(systemName: dictation.state == .recording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(dictation.state == .recording ? Color.dsRed : .dsGreenText)
                            .symbolEffect(.pulse, isActive: dictation.state == .recording)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(dictation.state == .recording ? "Detener dictado" : "Dictar comida")
                }
                .onChange(of: dictation.transcript) { _, transcript in
                    if !transcript.isEmpty {
                        text = transcript
                    }
                }
                if dictation.state == .recording {
                    Label("Escuchando…", systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(Color.dsGreenText)
                }
                if dictation.state == .denied {
                    Text("Para dictar, permite el micrófono en Ajustes → Foodia.")
                        .font(.caption)
                        .foregroundStyle(Color.dsOver)
                }
                Spacer()
                Button("Analizar") {
                    dictation.stop()
                    onSubmit(trimmed)
                }
                .buttonStyle(.dsPrimary)
                .disabled(trimmed.count < 3)
            }
            .padding(20)
            .background(Color.dsBackground)
            .navigationTitle("Describe tu comida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dictation.stop()
                        dismiss()
                    }
                    .tint(Color.dsGreenText)
                }
            }
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }
}
