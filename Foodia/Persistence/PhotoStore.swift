import UIKit

/// Guarda las fotos en disco (Application Support/Photos) y persiste solo el
/// nombre de archivo en SwiftData, para no inflar la base de datos.
enum PhotoStore {
    static var directory: URL {
        let base = URL.applicationSupportDirectory.appending(path: "Photos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func save(_ image: UIImage, maxDimension: CGFloat = 900) throws -> String {
        let scaled = downscale(image, maxDimension: maxDimension)
        guard let data = scaled.jpegData(compressionQuality: 0.8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let filename = UUID().uuidString + ".jpg"
        try data.write(to: directory.appending(path: filename))
        return filename
    }

    static func load(_ filename: String?) -> UIImage? {
        // Data(contentsOf:) usa la URL directa. `UIImage(contentsOfFile: url.path())`
        // fallaba: .path() devuelve el path percent-encoded (Application%20Support).
        guard let filename,
              let data = try? Data(contentsOf: directory.appending(path: filename)) else {
            return nil
        }
        return UIImage(data: data)
    }

    static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxDimension else { return image }
        let factor = maxDimension / maxSide
        let newSize = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        // scale = 1: el bitmap sale al tamaño de píxeles pedido. Por defecto el
        // renderer usa la escala del device (2-3×) y no reduciría los píxeles.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
