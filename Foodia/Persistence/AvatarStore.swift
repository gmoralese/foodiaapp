import UIKit

/// Cache local del avatar del usuario (uno por cuenta). El original vive en el
/// bucket privado `avatars` de Supabase; esto evita re-descargarlo y permite
/// mostrarlo offline. Sigue el patrón de `PhotoStore`.
enum AvatarStore {
    private static var directory: URL {
        let dir = URL.applicationSupportDirectory.appending(path: "Avatar", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var fileURL: URL { directory.appending(path: "avatar.jpg") }

    static func save(_ data: Data) {
        try? data.write(to: fileURL)
    }

    static func load() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Baja el avatar del bucket y lo cachea (best-effort).
    static func fetchAndCache(path: String) async {
        guard let data = try? await AuthService.shared.downloadAvatar(path) else { return }
        save(data)
    }
}
