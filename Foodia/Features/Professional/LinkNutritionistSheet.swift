import SwiftUI

/// Flujo para vincular un nutricionista: el paciente ingresa el código, ve
/// QUIÉN lo invita y QUÉ verá (consentimiento informado), y acepta con una
/// acción afirmativa. Todo con la posibilidad de rechazar.
struct LinkNutritionistSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var codeInput = ""
    @State private var state: LinkSheetState = .entering
    @FocusState private var codeFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch state {
                    case .entering, .searching, .failed:
                        entryView
                    case let .preview(preview), let .accepting(preview):
                        consentView(preview)
                    }
                }
                .padding(24)
            }
            .background(Color.dsBackground)
            .navigationTitle("Agregar nutricionista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear { codeFocused = true }
        }
    }

    // MARK: Ingreso del código

    private var entryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CÓDIGO DE INVITACIÓN")
                    .font(.dsSectionLabel)
                    .foregroundStyle(Color.dsTextTertiary)
                    .kerning(0.5)
                TextField("Ej. ABCD2345", text: $codeInput)
                    .font(.dsBigNumber)
                    .foregroundStyle(Color.dsTextPrimary)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($codeFocused)
                    .onSubmit { Task { await search() } }
                    .padding(14)
                    .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
            }
            Text("Pídele el código a tu nutricionista. Vence a los 7 días de generarlo.")
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)

            if case let .failed(error) = state {
                Text(errorText(error))
                    .font(.caption)
                    .foregroundStyle(Color.dsRed)
            }

            Button {
                Task { await search() }
            } label: {
                if case .searching = state {
                    ProgressView().tint(.white)
                } else {
                    Text("Buscar")
                }
            }
            .buttonStyle(.dsPrimary)
            .disabled(searchDisabled)
        }
    }

    private var searchDisabled: Bool {
        if case .searching = state { return true }
        return InviteCode.normalize(codeInput).isEmpty
    }

    // MARK: Consentimiento

    private func consentView(_ preview: InvitePreview) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                AvatarView(image: nil, name: preview.professionalName, size: 64)
                Text("\(preview.professionalName) quiere acompañarte")
                    .font(.dsSection)
                    .foregroundStyle(Color.dsTextPrimary)
                Text("Al aceptar, va a poder ver:")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                consentBullet("utensils-crossed", "Tus comidas con foto y sus macros")
                consentBullet("droplet", "Tu hidratación")
                consentBullet("scale", "Tu peso y medidas")
                consentBullet("target", "Tus metas diarias")
            }
            .padding(16)
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))

            Text("En consultas también podrá registrar mediciones y ajustar tus metas. No puede acceder a tu cuenta de Apple ni a otras apps o fotos de tu teléfono, y puedes dejar de compartir cuando quieras.")
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if case let .failed(error) = state {
                Text(errorText(error))
                    .font(.caption)
                    .foregroundStyle(Color.dsRed)
            }

            VStack(spacing: 10) {
                Button {
                    Task { await accept(preview) }
                } label: {
                    if case .accepting = state {
                        ProgressView().tint(.white)
                    } else {
                        Text("Aceptar y compartir")
                    }
                }
                .buttonStyle(.dsPrimary)
                .disabled(isAccepting)

                Button("Ahora no") { state = .entering }
                    .buttonStyle(.dsSecondary)
                    .disabled(isAccepting)
            }
        }
    }

    private func consentBullet(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            DSIcon(id: icon, size: 20, tint: .dsGreenText)
            Text(text)
                .font(.dsRowTitle)
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
        }
    }

    private var isAccepting: Bool {
        if case .accepting = state { return true }
        return false
    }

    // MARK: Acciones

    private func search() async {
        let code = InviteCode.normalize(codeInput)
        guard !code.isEmpty else { return }
        codeFocused = false
        state = .searching
        do {
            let preview = try await BackendClient.shared.previewInvite(code: code)
            state = .preview(preview)
        } catch let BackendClient.APIError.badStatus(status) {
            state = .failed(ProfessionalLinkError(status: status))
        } catch {
            state = .failed(.network)
        }
    }

    private func accept(_ preview: InvitePreview) async {
        state = .accepting(preview)
        do {
            _ = try await BackendClient.shared.acceptInvite(code: preview.code)
            dismiss()
        } catch let BackendClient.APIError.badStatus(status) {
            state = .failed(ProfessionalLinkError(status: status))
        } catch {
            state = .failed(.network)
        }
    }

    private func errorText(_ error: ProfessionalLinkError) -> LocalizedStringKey {
        switch error {
        case .notFound:
            return "No encontramos ese código. Revisa que esté bien escrito."
        case .expired:
            return "Esa invitación venció o ya no está disponible. Pídele una nueva a tu nutricionista."
        case .alreadyLinked:
            return "Ya tienes un vínculo activo con ese nutricionista."
        case .selfCode:
            return "Ese es tu propio código; no puedes vincularte contigo."
        case .network:
            return "No pudimos conectar. Revisa tu conexión e inténtalo de nuevo."
        }
    }
}
