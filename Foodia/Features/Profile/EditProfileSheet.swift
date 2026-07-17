import PhotosUI
import SwiftUI

/// Editar el perfil del usuario: nombre y avatar. El avatar se comprime y se
/// sube al bucket privado `avatars` de Supabase (se cachea local para offline).
struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = GoalsStore.shared.profile?.name ?? ""
    @State private var avatarImage: UIImage? = AvatarStore.load()
    @State private var avatarChanged = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showPicker = false
    @State private var uploading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    avatarPicker
                    nameField
                }
                .padding(24)
            }
            .background(Color.dsBackground)
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                        .disabled(uploading)
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadPicked(item) }
            }
        }
    }

    private var avatarPicker: some View {
        VStack(spacing: 10) {
            Button {
                showPicker = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(image: avatarImage, name: name, size: 96)
                    if uploading {
                        ProgressView()
                            .frame(width: 96, height: 96)
                            .background(.black.opacity(0.2), in: .circle)
                    } else {
                        DSIcon(id: "camera", size: 14, tint: .white)
                            .frame(width: 30, height: 30)
                            .background(Color.dsAccent, in: .circle)
                            .overlay(Circle().strokeBorder(Color.dsBackground, lineWidth: 2))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(uploading)
            .photosPicker(isPresented: $showPicker, selection: $photoItem, matching: .images)
            Text("Toca para cambiar tu foto")
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOMBRE")
                .font(.dsSectionLabel)
                .foregroundStyle(Color.dsTextTertiary)
                .kerning(0.5)
            TextField("Tu nombre", text: $name)
                .font(.dsRowTitle)
                .foregroundStyle(Color.dsTextPrimary)
                .textContentType(.name)
                .submitLabel(.done)
                .padding(14)
                .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
        }
    }

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        // Comprime al elegir: ~512 px de lado máximo.
        avatarImage = PhotoStore.downscale(image, maxDimension: 512)
        avatarChanged = true
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        GoalsStore.shared.updateName(trimmed.isEmpty ? nil : String(trimmed.prefix(80)))

        guard avatarChanged, let avatarImage,
              let data = avatarImage.jpegData(compressionQuality: 0.7) else {
            dismiss()
            return
        }
        AvatarStore.save(data) // cache local inmediata
        uploading = true
        Task {
            if let path = try? await AuthService.shared.uploadAvatar(data) {
                GoalsStore.shared.updateAvatarPath(path)
            }
            uploading = false
            dismiss()
        }
    }
}
