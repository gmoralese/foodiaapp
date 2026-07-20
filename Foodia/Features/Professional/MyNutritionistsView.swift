import SwiftUI

/// "Mis nutricionistas": lista de vínculos activos del paciente, con la opción
/// de revocar cada uno y de ingresar un código para vincular uno nuevo. Regla
/// dura del producto: acá aparecen TODOS los vínculos aceptados — nunca puede
/// existir uno invisible para el paciente.
struct MyNutritionistsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var links: [NutritionistLink] = []
    @State private var loading = true
    @State private var loadFailed = false
    @State private var showLinkSheet = false
    @State private var linkToRevoke: NutritionistLink?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                    } else if links.isEmpty {
                        EmptyStateView(
                            icon: "stethoscope",
                            title: "Sin nutricionista",
                            message: "Si trabajas con un nutricionista, ingresa el código que te compartió para que vea tu progreso.",
                            ctaTitle: "Ingresar código",
                            ctaSystemImage: "plus"
                        ) { showLinkSheet = true }
                    } else {
                        linkedList
                    }
                    if loadFailed {
                        Text("No pudimos cargar tus vínculos. Revisa tu conexión.")
                            .font(.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
                .padding(20)
            }
            .background(Color.dsBackground)
            .navigationTitle("Mis nutricionistas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showLinkSheet, onDismiss: { Task { await load() } }) {
                LinkNutritionistSheet()
            }
            .confirmationDialog(
                revokeTitle,
                isPresented: revokeDialogBinding,
                titleVisibility: .visible
            ) {
                Button("Dejar de compartir", role: .destructive) {
                    if let link = linkToRevoke { Task { await revoke(link) } }
                }
                Button("Cancelar", role: .cancel) { linkToRevoke = nil }
            }
        }
    }

    private var linkedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VINCULADOS")
                .font(.dsSectionLabel)
                .foregroundStyle(Color.dsTextTertiary)
                .kerning(0.5)
            VStack(spacing: 1) {
                ForEach(links) { link in
                    linkRow(link)
                }
            }
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
            Button {
                showLinkSheet = true
            } label: {
                Label("Ingresar otro código", systemImage: "plus")
            }
            .buttonStyle(.dsTinted)
            Text("Puedes dejar de compartir con cualquiera cuando quieras; el acceso se corta al instante.")
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)
        }
    }

    private func linkRow(_ link: NutritionistLink) -> some View {
        HStack(spacing: 12) {
            AvatarView(image: nil, name: link.professionalName, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(link.professionalName)
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                if let date = link.linkedAt {
                    Text("Vinculado \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
            Spacer()
            Button {
                linkToRevoke = link
            } label: {
                Text("Dejar de compartir")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dsRed)
            }
            .buttonStyle(.plain)
        }
        .padding(13)
        .contentShape(.rect)
    }

    private var revokeTitle: LocalizedStringKey {
        if let name = linkToRevoke?.professionalName {
            return "¿Dejar de compartir tu progreso con \(name)? Puedes volver a vincularte cuando quieras."
        }
        return "¿Dejar de compartir tu progreso?"
    }

    private var revokeDialogBinding: Binding<Bool> {
        Binding(
            get: { linkToRevoke != nil },
            set: { if !$0 { linkToRevoke = nil } }
        )
    }

    private func load() async {
        loading = links.isEmpty
        loadFailed = false
        do {
            links = try await BackendClient.shared.professionalLinks()
        } catch {
            loadFailed = true
        }
        loading = false
    }

    private func revoke(_ link: NutritionistLink) async {
        linkToRevoke = nil
        do {
            try await BackendClient.shared.revokeProfessionalLink(id: link.id)
            links.removeAll { $0.id == link.id }
        } catch {
            loadFailed = true
        }
    }
}
