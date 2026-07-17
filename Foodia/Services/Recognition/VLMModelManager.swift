import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLMCommon
import MLXVLM
import Tokenizers

/// Gestiona el ciclo de vida del VLM local: descarga on-demand desde Hugging Face
/// (una sola vez, queda en Documents), carga en memoria y borrado.
///
/// Modelo por defecto: LFM2.5-VL-1.6B 4-bit (Liquid AI) — en las pruebas con
/// platos compuestos produjo JSON válido y la cobertura más completa. Licencia
/// LFM Open License v1.0: uso comercial libre hasta USD 10M de facturación anual
/// (FastVLM quedó descartado: su licencia es solo investigación). ~1 GB.
/// Alternativa Apache 2.0 pura: VLMRegistry.qwen2VL2BInstruct4Bit.
@Observable
final class VLMModelManager {
    enum State: Equatable {
        case notDownloaded
        case downloading(Double)
        case loading
        case ready
        case failed(String)
    }

    static let shared = VLMModelManager()

    static let modelID = "mlx-community/LFM2.5-VL-1.6B-4bit"
    static let configuration = VLMRegistry.lfm2_5_vl_1_6B_4bit
    static let approximateSize = "1 GB"
    static let displayName = "LFM2.5-VL 1.6B"

    private(set) var state: State = .notDownloaded
    private(set) var container: ModelContainer?

    /// Directorio base del cache de modelos (en Documents: no lo purga el sistema).
    private let cacheDirectory: URL
    /// Carpeta específica del modelo dentro del cache (layout de Hugging Face hub).
    private let modelDirectory: URL

    init() {
        cacheDirectory = URL.documentsDirectory.appending(path: "models", directoryHint: .isDirectory)
        let folder = "models--" + Self.modelID.replacingOccurrences(of: "/", with: "--")
        modelDirectory = cacheDirectory.appending(path: folder, directoryHint: .isDirectory)
    }

    var isDownloaded: Bool {
        Self.hasWeights(at: modelDirectory)
    }

    /// Descarga (si hace falta) y carga el modelo. Idempotente.
    func prepare() async {
        if container != nil {
            state = .ready
            return
        }
        if case .downloading = state { return }
        if case .loading = state { return }

        state = isDownloaded ? .loading : .downloading(0)
        do {
            let client = HubClient(cache: HubCache(location: .fixed(directory: cacheDirectory)))
            let container = try await VLMModelFactory.shared.loadContainer(
                from: #hubDownloader(client),
                using: #huggingFaceTokenizerLoader(),
                configuration: Self.configuration
            ) { progress in
                Task { @MainActor [weak self] in
                    guard let self, self.container == nil else { return }
                    if progress.fractionCompleted < 1.0 {
                        self.state = .downloading(progress.fractionCompleted)
                    } else {
                        self.state = .loading
                    }
                }
            }
            self.container = container
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func removeDownload() {
        container = nil
        try? FileManager.default.removeItem(at: modelDirectory)
        state = .notDownloaded
    }

    private nonisolated static func hasWeights(at directory: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: nil
        ) else { return false }
        for case let url as URL in enumerator where url.pathExtension == "safetensors" {
            return true
        }
        return false
    }
}
